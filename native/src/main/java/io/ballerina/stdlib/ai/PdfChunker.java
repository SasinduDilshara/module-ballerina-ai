/*
 *  Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 *  WSO2 LLC. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

package io.ballerina.stdlib.ai;

import dev.langchain4j.data.segment.TextSegment;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.io.RandomAccessReadBuffer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.encryption.InvalidPasswordException;
import org.apache.pdfbox.text.PDFTextStripper;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static java.util.stream.IntStream.range;

class PdfChunker {

    private static final Set<String> NON_MERGEABLE_TYPES = Set.of("pdf_page");
    private static final String PAGE_TYPE = "pdf_page";

    enum PdfChunkStrategy {
        PDF_PAGE, PDF_PARAGRAPH, PDF_SENTENCE, PDF_WORD, PDF_CHARACTER;

        List<RecursiveChunker.Splitter> getSplitters() {
            List<RecursiveChunker.Splitter> splitters = new ArrayList<>();
            switch (this) {
                case PDF_PARAGRAPH:
                    splitters.add(new RecursiveChunker.SimpleDelimiterSplitter("\n\n"));
                    // fall through
                case PDF_SENTENCE:
                    splitters.add(new RecursiveChunker.SimpleDelimiterSplitter("\n"));
                    splitters.add(RecursiveChunker.Splitter.createSentenceSplitter());
                    // fall through
                case PDF_WORD:
                    splitters.add(RecursiveChunker.Splitter.createWordSplitter());
                    // fall through
                case PDF_CHARACTER:
                    splitters.add(RecursiveChunker.Splitter.createCharacterSplitter());
                    break;
                case PDF_PAGE:
                    // Page strategy uses its own pipeline (handled in chunk method).
                    break;
            }
            return splitters;
        }
    }

    record PageContent(int pageNumber, String text) {
    }

    record ExtractionResult(List<PageContent> pages, int totalPages) {
    }

    static List<TextSegment> chunk(byte[] pdfBytes, PdfChunkStrategy strategy, int maxChunkSize,
                                   int maxOverlapSize, boolean sortByPosition, String password)
            throws IOException {
        if (maxChunkSize <= 0) {
            throw new IllegalArgumentException("maxChunkSize must be greater than 0");
        }
        if (maxOverlapSize > maxChunkSize) {
            throw new IllegalArgumentException("maxOverlapSize must be less than or equal to maxChunkSize");
        }
        ExtractionResult extraction = extractPages(pdfBytes, password, sortByPosition);
        if (strategy == PdfChunkStrategy.PDF_PAGE) {
            return chunkByPage(extraction, maxChunkSize, maxOverlapSize);
        }
        return chunkConcatenated(extraction, strategy, maxChunkSize, maxOverlapSize);
    }

    private static ExtractionResult extractPages(byte[] pdfBytes, String password, boolean sortByPosition)
            throws IOException {
        try (PDDocument document = password == null
                ? Loader.loadPDF(new RandomAccessReadBuffer(pdfBytes))
                : Loader.loadPDF(new RandomAccessReadBuffer(pdfBytes), password)) {
            int totalPages = document.getNumberOfPages();
            List<PageContent> pages = new ArrayList<>(totalPages);
            for (int page = 1; page <= totalPages; page++) {
                PDFTextStripper stripper = new PDFTextStripper();
                stripper.setSortByPosition(sortByPosition);
                stripper.setStartPage(page);
                stripper.setEndPage(page);
                String text = stripper.getText(document);
                pages.add(new PageContent(page, text == null ? "" : text));
            }
            return new ExtractionResult(pages, totalPages);
        } catch (InvalidPasswordException e) {
            if (password == null) {
                throw new IOException("PDF is encrypted; supply password", e);
            }
            throw new IOException("Incorrect PDF password", e);
        }
    }

    private static List<TextSegment> chunkByPage(ExtractionResult extraction, int maxChunkSize, int maxOverlapSize) {
        List<RecursiveChunker.Chunk> allChunks = new ArrayList<>();
        RecursiveChunker chunker = new RecursiveChunker(NON_MERGEABLE_TYPES);
        List<RecursiveChunker.Splitter> fallbackSplitters = List.of(
                new RecursiveChunker.SimpleDelimiterSplitter("\n\n"),
                new RecursiveChunker.SimpleDelimiterSplitter("\n"),
                RecursiveChunker.Splitter.createSentenceSplitter(),
                RecursiveChunker.Splitter.createWordSplitter(),
                RecursiveChunker.Splitter.createCharacterSplitter()
        );

        int totalPages = extraction.totalPages();
        for (PageContent page : extraction.pages()) {
            String text = page.text();
            if (text == null || text.isBlank()) {
                continue;
            }
            Map<String, String> pageMetadata = new HashMap<>();
            pageMetadata.put("pageNumber", String.valueOf(page.pageNumber()));
            pageMetadata.put("totalPages", String.valueOf(totalPages));

            List<RecursiveChunker.Chunk> pageChunks;
            if (text.length() <= maxChunkSize) {
                // Single chunk for the page; tag as non-mergeable so subsequent pages
                // do not get merged into the same chunk.
                Map<String, String> metadata = new HashMap<>(pageMetadata);
                metadata.put("type", PAGE_TYPE);
                pageChunks = List.of(new RecursiveChunker.Chunk(text, Collections.unmodifiableMap(metadata)));
            } else {
                // Recursively split the page; share pageNumber metadata across all sub-chunks.
                pageChunks = chunker.chunkUsingSplitters(text, fallbackSplitters, maxChunkSize, maxOverlapSize);
                pageChunks = applyPageMetadata(pageChunks, pageMetadata);
            }
            allChunks.addAll(pageChunks);
        }
        return toTextSegments(allChunks);
    }

    private static List<RecursiveChunker.Chunk> applyPageMetadata(List<RecursiveChunker.Chunk> chunks,
                                                                  Map<String, String> pageMetadata) {
        List<RecursiveChunker.Chunk> result = new ArrayList<>(chunks.size());
        long previousId = -1L;
        for (RecursiveChunker.Chunk chunk : chunks) {
            Map<String, String> merged = new HashMap<>(pageMetadata);
            merged.putAll(chunk.metadata());
            if (previousId >= 0) {
                merged.put("prev", String.valueOf(previousId));
            }
            RecursiveChunker.Chunk linked = new RecursiveChunker.Chunk(chunk.piece(),
                    Collections.unmodifiableMap(merged));
            result.add(linked);
            previousId = linked.id();
        }
        return result;
    }

    private static List<TextSegment> chunkConcatenated(ExtractionResult extraction, PdfChunkStrategy strategy,
                                                       int maxChunkSize, int maxOverlapSize) {
        StringBuilder builder = new StringBuilder();
        for (PageContent page : extraction.pages()) {
            if (page.text() == null || page.text().isBlank()) {
                continue;
            }
            if (builder.length() > 0) {
                builder.append("\n\n");
            }
            builder.append(page.text());
        }
        String content = builder.toString();
        if (content.isBlank()) {
            return List.of();
        }
        RecursiveChunker chunker = new RecursiveChunker(Set.of());
        List<RecursiveChunker.Chunk> chunks = chunker.chunkUsingSplitters(content, strategy.getSplitters(),
                maxChunkSize, maxOverlapSize);
        Map<String, String> docMetadata = Map.of("totalPages", String.valueOf(extraction.totalPages()));
        List<RecursiveChunker.Chunk> annotated = new ArrayList<>(chunks.size());
        for (RecursiveChunker.Chunk chunk : chunks) {
            Map<String, String> merged = new HashMap<>(docMetadata);
            merged.putAll(chunk.metadata());
            annotated.add(new RecursiveChunker.Chunk(chunk.piece(), Collections.unmodifiableMap(merged)));
        }
        return toTextSegments(annotated);
    }

    private static List<TextSegment> toTextSegments(List<RecursiveChunker.Chunk> chunks) {
        return range(0, chunks.size())
                .mapToObj(i -> chunks.get(i).toTextSegment(i))
                .toList();
    }
}
