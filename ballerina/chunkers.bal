// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/jballerina.java;
import ballerina/math.vector;

# Represents a chunker that can process documents and return chunks.
public type Chunker isolated object {
    # Chunks the provided document.
    # + document - The input document to be chunked
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error;
};

# Represents a Genereric document chunker.
# Provides functionality to recursively chunk a text document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
public isolated class GenericRecursiveChunker {
    *Chunker;
    private final int maxChunkSize;
    private final int maxOverlapSize;
    private final RecursiveChunkStrategy strategy;

    # Initializes a new instance of the `GenericRecursiveChunker`.
    #
    # + maxChunkSize - Maximum number of characters allowed per chunk
    # + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating the next one.
    # This overlap is made of complete sentences taken in reverse from the previous chunk, without exceeding
    # this limit. It helps maintain context between chunks during splitting.
    # + strategy - The recursive chunking strategy to use. Defaults to `PARAGRAPH`
    public isolated function init(int maxChunkSize = 200, int maxOverlapSize = 40,
            RecursiveChunkStrategy strategy = PARAGRAPH) {
        self.maxChunkSize = maxChunkSize;
        self.maxOverlapSize = maxOverlapSize;
        self.strategy = strategy;
    }

    # Chunks the provided document.
    # + document - The input document to be chunked
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error {
        return chunkDocumentRecursively(document, self.maxChunkSize, self.maxOverlapSize, self.strategy);
    }
}

# Represents a Markdown document chunker.
# Provides functionality to recursively chunk a markdown document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
public isolated class MarkdownChunker {
    *Chunker;
    private final int maxChunkSize;
    private final int maxOverlapSize;
    private final MarkdownChunkStrategy strategy;

    # Initializes a new instance of the `MarkdownChunker`.
    #
    # + maxChunkSize - Maximum number of characters allowed per chunk
    # + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating
    # the next one.
    # + strategy - The markdown chunking strategy to use. Defaults to `MARKDOWN_HEADER`
    public isolated function init(int maxChunkSize = 200, int maxOverlapSize = 40,
            MarkdownChunkStrategy strategy = MARKDOWN_HEADER) {
        self.maxChunkSize = maxChunkSize;
        self.maxOverlapSize = maxOverlapSize;
        self.strategy = strategy;
    }

    # Chunks the provided document.
    # + document - The input document to be chunked
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error {
        return chunkMarkdownDocument(document, self.maxChunkSize, self.maxOverlapSize, self.strategy);
    }
}

# Represents an HTML document chunker.
# Provides functionality to recursively chunk a HTML document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
public isolated class HtmlChunker {
    *Chunker;
    private final int maxChunkSize;
    private final int maxOverlapSize;
    private final HtmlChunkStrategy strategy;

    # Initializes a new instance of the `HtmlChunker`.
    #
    # + maxChunkSize - Maximum number of characters allowed per chunk
    # + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating
    # the next one
    # + strategy - The HTML chunking strategy to use. Defaults to `HTML_HEADER`.
    public isolated function init(int maxChunkSize = 200, int maxOverlapSize = 40,
            HtmlChunkStrategy strategy = HTML_HEADER) {
        self.maxChunkSize = maxChunkSize;
        self.maxOverlapSize = maxOverlapSize;
        self.strategy = strategy;
    }

    # Chunks the provided document.
    #
    # + document - The input document to be chunked
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error {
        return chunkHtmlDocument(document, self.maxChunkSize, self.maxOverlapSize, self.strategy);
    }
}

# Provides functionality to recursively chunk a text document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
#
# + document - The input document or string to be chunked
# + maxChunkSize - Maximum number of characters allowed per chunk
# + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating the next one.
# This overlap is made of complete sentences taken in reverse from the previous chunk, without exceeding
# this limit. It helps maintain context between chunks during splitting.
# + strategy - The recursive chunking strategy to use. Defaults to `PARAGRAPH`
# + return - An array of chunks, or an `ai:Error` if the chunking fails.
public isolated function chunkDocumentRecursively(Document|string document, int maxChunkSize = 200, int maxOverlapSize = 40,
        RecursiveChunkStrategy strategy = PARAGRAPH) returns Chunk[]|Error {
    if document !is TextDocument|TextChunk && document !is string {
        return error Error("Only text documents are supported for chunking");
    }
    TextDocument|TextChunk textDocument = document is string ? <TextDocument>{content: document} : document;
    return chunkTextDocument(textDocument, maxChunkSize, maxOverlapSize, strategy);
}

isolated function chunkTextDocument(TextDocument|TextChunk document, int chunkSize, int overlapSize,
        RecursiveChunkStrategy chunkStrategy, typedesc<TextChunk> textChunkType = TextChunk)
        returns TextChunk[]|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.Chunkers"
} external;

# Provides functionality to recursively chunk a markdown document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
#
# + document - The input document to be chunked
# + maxChunkSize - Maximum number of characters allowed per chunk
# + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating the next one.
# + strategy - The markdown chunking strategy to use. Defaults to `MARKDOWN_HEADER`
# + return - An array of chunks, or an `ai:Error` if the chunking fails.
public isolated function chunkMarkdownDocument(Document document, int maxChunkSize, int maxOverlapSize,
        MarkdownChunkStrategy strategy = MARKDOWN_HEADER) returns TextChunk[]|Error {
    return chunkMarkdownDocumentInner(document, maxChunkSize, maxOverlapSize, strategy);
}

# Provides functionality to recursively chunk a HTML document using a configurable strategy.
#
# The chunking process begins with the specified strategy and recursively falls back to
# finer-grained strategies if the content exceeds the configured `maxChunkSize`. Overlapping content
# between chunks can be controlled using `maxOverlapSize`.
#
# + document - The input document to be chunked
# + maxChunkSize - Maximum number of characters allowed per chunk
# + maxOverlapSize - Maximum number of characters to reuse from the end of the previous chunk when creating the next one.
# + strategy - The HTML chunking strategy to use. Defaults to `HTML_HEADER`
# + return - An array of chunks, or an `ai:Error` if the chunking fails.
public isolated function chunkHtmlDocument(Document document, int maxChunkSize, int maxOverlapSize,
        HtmlChunkStrategy strategy = HTML_HEADER) returns TextChunk[]|Error {
    return chunkHtmlDocumentInner(document, maxChunkSize, maxOverlapSize, strategy);
}

isolated function chunkMarkdownDocumentInner(Document document, int chunkSize, int overlapSize,
        MarkdownChunkStrategy chunkStrategy, typedesc<TextChunk> textChunkType = TextChunk) returns TextChunk[]|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.Chunkers",
    name: "chunkMarkdownDocument"
} external;

isolated function chunkHtmlDocumentInner(Document document, int chunkSize, int overlapSize,
        HtmlChunkStrategy chunkStrategy, typedesc<TextChunk> textChunkType = TextChunk) returns TextChunk[]|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.Chunkers",
    name: "chunkHtmlDocument"
} external;

# Represents the available strategies for recursively chunking a document.
#
# Each strategy attempts to include as much content as possible using a specific unit (such as paragraph or sentence).
# If the content exceeds the defined `maxChunkSize` in `RecursiveChunker`, the strategy recursively falls back
# to a finer-grained unit until the content fits within the limit.
public enum RecursiveChunkStrategy {

    # Splits text by individual characters.
    CHARACTER,

    # Splits text by words. Falls back to CHARACTER if the chunk exceeds the size limit.
    #
    # Word boundaries are detected using at least one space character (" ").
    # Any extra whitespace before or after words, such as multiple spaces or newline characters, is ignored.
    # Examples of valid word separators include " ", "  ", "\n", and " \n ".
    # When multiple words fit within the limit, they are joined together using a single space (" ").
    WORD,

    # Splits text by lines. Falls back to WORD, then CHARACTER, if the chunk exceeds the size limit.
    #
    # Line boundaries are identified using at least one newline character ("\n").
    # Any extra whitespace before or after lines is ignored.
    # Examples of valid line separators include "\n", "\n\n", " \n", and "\n ".
    # When multiple lines fit within the limit, they are joined together using a single newline ("\n").
    LINE,

    # Splits text by sentences. Falls back to WORD, then CHARACTER, if the chunk exceeds the size limit.
    #
    # Sentence boundaries are detected using OpenNLP's sentence detector (https://opennlp.apache.org).
    # When multiple sentences fit within the limit, they are joined together using a single space (" ").
    SENTENCE,

    # Splits text by paragraphs. Falls back to SENTENCE, then WORD, then CHARACTER, if the chunk exceeds the size limit.
    #
    # Paragraph boundaries are detected using at least two newline characters ("\n\n").
    # Any extra whitespace before, between, or after paragraphs is ignored.
    # Examples of valid paragraph separators include "\n\n", "\n\n\n", "\n \n", and " \n \n ".
    # When multiple paragraphs fit within the limit, they are joined together using a double newline ("\n\n").
    PARAGRAPH
}

# Represents the available strategies for chunking a markdown document.
#
# Each strategy attempts to include as much content as possible using a specific unit (such as paragraph or sentence).
# If the content exceeds the defined `maxChunkSize` the strategy recursively falls back to a finer-grained unit until
# the content fits within the limit.
public enum MarkdownChunkStrategy {

    # Split text by markdown headers. Starting with h2 recursively falls back to h3, h4, h5, and h6. If chunk is still
    # too large, it falls back to the CODE_BLOCK, HORIZONTAL_LINE, PARAGRAPH, LINE, SENTENCE, WORD, and CHARACTER
    # strategies in that order.
    MARKDOWN_HEADER,

    # Split text by code blocks. Chunks that containing the code blocks will have annotation type "code_block". If
    # language is specified, will add "language" annotation to the chunk. Chunks produced by code blocks will not be
    # merged with other chunks even if combined chunk size is less than `maxChunkSize`.
    CODE_BLOCK,

    # Split text by horizontal lines. Check for patterns (`***`, `---`, `___`). If chunk is still too large, it falls back to the
    # PARAGRAPH strategy.
    HORIZONTAL_LINE,

    PARAGRAPH,

    LINE,

    SENTENCE,

    WORD,

    CHARACTER
}

# Represents the available strategies for chunking a HTML document.
#
# Each strategy attempts to include as much content as possible using a specific unit (such as paragraph or sentence).
# If the content exceeds the defined `maxChunkSize` the strategy recursively falls back to a finer-grained unit until
# the content fits within the limit.
public enum HtmlChunkStrategy {

    # Split text by HTML headers. Starting with `<h1>...</h1>` recursively falls back to `<h2>`, `<h3>`, `<h4>`,
    # `<h5>`, and `<h6>`. If chunk is still too large, it falls back to the HTML_PARAGRAPH, HTML_LINE, SENTENCE, WORD, and
    # CHARACTER strategies in that order.
    HTML_HEADER,

    # Split text by HTML paragraphs (`<p>...</p>`). If chunk is still too large, it falls back to the HTML_LINE, SENTENCE, WORD, and
    # CHARACTER strategies in that order.
    HTML_PARAGRAPH,

    # Split text by HTML breaks (`<br>`). If chunk is still too large, it falls back to the SENTENCE, WORD, and
    # CHARACTER strategies in that order.
    HTML_LINE,

    SENTENCE,

    WORD,

    CHARACTER
}

# Represents the strategies used to derive a similarity-distance threshold
# when determining where to place chunk boundaries in `SemanticChunker`.
#
# All strategies operate on the array of cosine distances between successive
# sentence-window embeddings. The default amount for each strategy matches
# the defaults popularized by LangChain's `SemanticChunker`.
public enum BreakpointThresholdType {
    # The threshold is the Nth percentile of distances (default amount: `95.0`).
    PERCENTILE,
    # The threshold is `mean(distances) + amount * stddev(distances)` (default amount: `3.0`).
    STANDARD_DEVIATION,
    # The threshold is `mean(distances) + amount * iqr(distances)` (default amount: `1.5`).
    INTERQUARTILE,
    # The threshold is the Nth percentile of the gradient of distances
    # (default amount: `95.0`). Useful when content is highly correlated.
    GRADIENT
}

# Represents a Semantic document chunker.
# Splits text using embedding similarity between adjacent sentence windows
# instead of fixed character/word boundaries. Suitable for prose where
# topic transitions matter more than chunk size.
#
# The chunker first splits the input into sentences, builds a contextual
# window around each sentence using `bufferSize` neighbors on each side,
# embeds each window, computes cosine distances between consecutive windows,
# and inserts a chunk boundary wherever a distance exceeds the threshold
# derived from `breakpointThresholdType` and `breakpointThresholdAmount`.
public isolated class SemanticChunker {
    *Chunker;
    private final EmbeddingProvider embeddingModel;
    private final int bufferSize;
    private final BreakpointThresholdType breakpointThresholdType;
    private final float breakpointThresholdAmount;
    private final int minChunkSize;
    private final int maxChunkSize;

    # Initializes a new instance of the `SemanticChunker`.
    #
    # + embeddingModel - The embedding provider used to embed sentence windows
    # + bufferSize - Number of neighboring sentences to concatenate on each side of
    # a sentence before embedding it. Higher values smooth the distance signal.
    # + breakpointThresholdType - The statistic used to derive the split threshold
    # + breakpointThresholdAmount - The numeric amount for the threshold. When `()`, the
    # type-specific default is used (`95.0` for `PERCENTILE`/`GRADIENT`, `3.0` for
    # `STANDARD_DEVIATION`, `1.5` for `INTERQUARTILE`).
    # + minChunkSize - Minimum character length of a produced chunk. Smaller
    # candidate chunks are absorbed into the next chunk.
    # + maxChunkSize - Optional upper bound on chunk size. When set, any semantic
    # chunk that exceeds this length is further split using the recursive
    # `SENTENCE` strategy. Use `0` (the default) to disable this safety net.
    # + return - An `ai:Error` if the configuration is invalid; otherwise `nil`
    public isolated function init(EmbeddingProvider embeddingModel,
            int bufferSize = 1,
            BreakpointThresholdType breakpointThresholdType = PERCENTILE,
            float? breakpointThresholdAmount = (),
            int minChunkSize = 0,
            int maxChunkSize = 0) returns Error? {
        if bufferSize < 0 {
            return error Error("bufferSize must be non-negative");
        }
        if minChunkSize < 0 {
            return error Error("minChunkSize must be non-negative");
        }
        if maxChunkSize < 0 {
            return error Error("maxChunkSize must be non-negative");
        }
        float resolvedAmount = breakpointThresholdAmount ?: defaultThresholdAmount(breakpointThresholdType);
        check validateThresholdAmount(breakpointThresholdType, resolvedAmount);
        self.embeddingModel = embeddingModel;
        self.bufferSize = bufferSize;
        self.breakpointThresholdType = breakpointThresholdType;
        self.breakpointThresholdAmount = resolvedAmount;
        self.minChunkSize = minChunkSize;
        self.maxChunkSize = maxChunkSize;
    }

    # Chunks the provided document.
    # + document - The input document to be chunked
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error {
        return chunkDocumentSemantically(document, self.embeddingModel,
                self.bufferSize, self.breakpointThresholdType,
                self.breakpointThresholdAmount, self.minChunkSize, self.maxChunkSize);
    }
}

# Splits a text document using embedding-similarity breakpoints.
#
# The chunking pipeline is:
# 1. Split the content into sentences.
# 2. Build a context window around each sentence using `bufferSize` neighbors.
# 3. Embed every window in one batch through `embeddingModel`.
# 4. Compute cosine distances between consecutive embeddings.
# 5. Derive a numeric threshold from those distances using the chosen strategy.
# 6. Emit a chunk boundary wherever the distance exceeds the threshold.
#
# + document - The input document or string to be chunked
# + embeddingModel - The embedding provider used to embed sentence windows
# + bufferSize - Number of neighboring sentences to concatenate around each sentence
# + breakpointThresholdType - The statistic used to derive the split threshold
# + breakpointThresholdAmount - The numeric amount for the threshold (uses the
# type-specific default when `()`)
# + minChunkSize - Minimum character length of a chunk
# + maxChunkSize - Optional upper bound on chunk size; `0` disables the safety net
# + return - An array of chunks, or an `ai:Error` if the chunking fails
public isolated function chunkDocumentSemantically(Document|string document,
        EmbeddingProvider embeddingModel,
        int bufferSize = 1,
        BreakpointThresholdType breakpointThresholdType = PERCENTILE,
        float? breakpointThresholdAmount = (),
        int minChunkSize = 0,
        int maxChunkSize = 0) returns Chunk[]|Error {
    if document !is TextDocument|TextChunk && document !is string {
        return error Error("Only text documents are supported for chunking");
    }
    if bufferSize < 0 {
        return error Error("bufferSize must be non-negative");
    }
    if minChunkSize < 0 {
        return error Error("minChunkSize must be non-negative");
    }
    if maxChunkSize < 0 {
        return error Error("maxChunkSize must be non-negative");
    }

    TextDocument|TextChunk textDocument = document is string ? <TextDocument>{content: document} : document;
    string content = textDocument.content;

    if content.trim().length() == 0 {
        return [];
    }

    string[] sentences = splitIntoSentences(content);
    if sentences.length() == 0 {
        return [];
    }
    if sentences.length() == 1 {
        return [buildSemanticChunk(textDocument, sentences[0], 0)];
    }

    float resolvedAmount = breakpointThresholdAmount ?: defaultThresholdAmount(breakpointThresholdType);
    check validateThresholdAmount(breakpointThresholdType, resolvedAmount);

    string[] windows = buildSentenceWindows(sentences, bufferSize);
    Chunk[] windowChunks = from string w in windows
        select <TextChunk>{content: w};
    Embedding[] embeddings = check embeddingModel->batchEmbed(windowChunks);
    if embeddings.length() != windows.length() {
        return error Error("Mismatch between number of sentence windows and embeddings");
    }
    Vector[] denseEmbeddings = check toDenseVectors(embeddings);

    float[] distances = computeAdjacentDistances(denseEmbeddings);
    int[] breakpoints = computeBreakpoints(distances, breakpointThresholdType, resolvedAmount);

    string[] chunkTexts = assembleSemanticChunks(sentences, breakpoints, minChunkSize);

    Chunk[] result = [];
    int index = 0;
    foreach string text in chunkTexts {
        if maxChunkSize > 0 && text.length() > maxChunkSize {
            Chunk[] subChunks = check chunkDocumentRecursively(text, maxChunkSize, 0, SENTENCE);
            foreach Chunk sub in subChunks {
                anydata subContent = sub.content;
                string subText = subContent is string ? subContent : subContent.toString();
                result.push(buildSemanticChunk(textDocument, subText, index));
                index += 1;
            }
        } else {
            result.push(buildSemanticChunk(textDocument, text, index));
            index += 1;
        }
    }
    return result;
}

isolated function defaultThresholdAmount(BreakpointThresholdType breakpointThresholdType) returns float {
    match breakpointThresholdType {
        STANDARD_DEVIATION => {
            return 3.0;
        }
        INTERQUARTILE => {
            return 1.5;
        }
    }
    return 95.0;
}

isolated function validateThresholdAmount(BreakpointThresholdType breakpointThresholdType,
        float amount) returns Error? {
    match breakpointThresholdType {
        PERCENTILE|GRADIENT => {
            if amount < 0.0 || amount > 100.0 {
                return error Error("breakpointThresholdAmount must be in [0, 100] for "
                        + breakpointThresholdType + " strategy");
            }
        }
        STANDARD_DEVIATION|INTERQUARTILE => {
            if amount <= 0.0 {
                return error Error("breakpointThresholdAmount must be greater than 0 for "
                        + breakpointThresholdType + " strategy");
            }
        }
    }
}

isolated function splitIntoSentences(string content) returns string[] {
    string[] sentences = [];
    int n = content.length();
    if n == 0 {
        return sentences;
    }
    int sentenceStart = 0;
    int i = 0;
    while i < n {
        string ch = content.substring(i, i + 1);
        if (ch == "." || ch == "!" || ch == "?") {
            int j = i + 1;
            // Consume runs of consecutive terminators (e.g. "...", "!?").
            while j < n {
                string next = content.substring(j, j + 1);
                if next != "." && next != "!" && next != "?" {
                    break;
                }
                j += 1;
            }
            boolean isBoundary = false;
            if j >= n {
                isBoundary = true;
            } else {
                string trailing = content.substring(j, j + 1);
                if trailing == " " || trailing == "\t" || trailing == "\n" || trailing == "\r" {
                    isBoundary = true;
                }
            }
            if isBoundary {
                string sentence = content.substring(sentenceStart, j).trim();
                if sentence.length() > 0 {
                    sentences.push(sentence);
                }
                while j < n {
                    string ws = content.substring(j, j + 1);
                    if ws != " " && ws != "\t" && ws != "\n" && ws != "\r" {
                        break;
                    }
                    j += 1;
                }
                sentenceStart = j;
                i = j;
                continue;
            }
            i = j;
            continue;
        }
        i += 1;
    }
    if sentenceStart < n {
        string remaining = content.substring(sentenceStart, n).trim();
        if remaining.length() > 0 {
            sentences.push(remaining);
        }
    }
    return sentences;
}

isolated function buildSentenceWindows(string[] sentences, int bufferSize) returns string[] {
    int n = sentences.length();
    string[] windows = [];
    foreach int i in 0 ..< n {
        string window = "";
        int startIndex = i - bufferSize;
        if startIndex < 0 {
            startIndex = 0;
        }
        int endIndex = i + bufferSize + 1;
        if endIndex > n {
            endIndex = n;
        }
        foreach int j in startIndex ..< endIndex {
            if window.length() > 0 {
                window += " ";
            }
            window += sentences[j];
        }
        windows.push(window);
    }
    return windows;
}

isolated function toDenseVectors(Embedding[] embeddings) returns Vector[]|Error {
    Vector[] dense = [];
    foreach Embedding embedding in embeddings {
        if embedding is Vector {
            dense.push(embedding);
        } else {
            return error Error("SemanticChunker requires dense Vector embeddings; "
                    + "sparse and hybrid embeddings are not supported");
        }
    }
    return dense;
}

isolated function computeAdjacentDistances(Vector[] embeddings) returns float[] {
    float[] distances = [];
    int n = embeddings.length();
    foreach int i in 0 ..< n - 1 {
        float similarity = vector:cosineSimilarity(embeddings[i], embeddings[i + 1]);
        distances.push(1.0 - similarity);
    }
    return distances;
}

isolated function computeBreakpoints(float[] distances, BreakpointThresholdType breakpointThresholdType,
        float amount) returns int[] {
    if distances.length() == 0 {
        return [];
    }
    float threshold = computeThreshold(distances, breakpointThresholdType, amount);
    float[] signal = breakpointThresholdType == GRADIENT ? computeGradient(distances) : distances;
    int[] breakpoints = [];
    foreach int i in 0 ..< signal.length() {
        if signal[i] > threshold {
            breakpoints.push(i);
        }
    }
    return breakpoints;
}

isolated function computeThreshold(float[] distances, BreakpointThresholdType breakpointThresholdType,
        float amount) returns float {
    match breakpointThresholdType {
        PERCENTILE => {
            return percentile(distances, amount);
        }
        STANDARD_DEVIATION => {
            float meanValue = mean(distances);
            float stddev = standardDeviation(distances, meanValue);
            return meanValue + amount * stddev;
        }
        INTERQUARTILE => {
            float meanValue = mean(distances);
            float q1 = percentile(distances, 25.0);
            float q3 = percentile(distances, 75.0);
            return meanValue + amount * (q3 - q1);
        }
        GRADIENT => {
            float[] gradient = computeGradient(distances);
            return percentile(gradient, amount);
        }
    }
    return percentile(distances, amount);
}

isolated function computeGradient(float[] values) returns float[] {
    int n = values.length();
    if n == 0 {
        return [];
    }
    if n == 1 {
        return [0.0];
    }
    float[] gradient = [];
    foreach int i in 0 ..< n {
        if i == 0 {
            gradient.push(values[1] - values[0]);
        } else if i == n - 1 {
            gradient.push(values[n - 1] - values[n - 2]);
        } else {
            gradient.push((values[i + 1] - values[i - 1]) / 2.0);
        }
    }
    return gradient;
}

isolated function percentile(float[] values, float p) returns float {
    int n = values.length();
    if n == 0 {
        return 0.0;
    }
    float[] sorted = values.clone();
    sorted = sorted.sort();
    if n == 1 {
        return sorted[0];
    }
    float rank = (p / 100.0) * <float>(n - 1);
    // Use floor explicitly; `<int>` on a non-integer float rounds to nearest-even.
    int lower = <int>float:floor(rank);
    if lower < 0 {
        lower = 0;
    }
    int upper = lower + 1;
    if upper >= n {
        return sorted[n - 1];
    }
    float fraction = rank - <float>lower;
    return sorted[lower] + fraction * (sorted[upper] - sorted[lower]);
}

isolated function mean(float[] values) returns float {
    int n = values.length();
    if n == 0 {
        return 0.0;
    }
    float total = 0.0;
    foreach float v in values {
        total += v;
    }
    return total / <float>n;
}

isolated function standardDeviation(float[] values, float meanValue) returns float {
    int n = values.length();
    if n == 0 {
        return 0.0;
    }
    float sumSquares = 0.0;
    foreach float v in values {
        float diff = v - meanValue;
        sumSquares += diff * diff;
    }
    return float:sqrt(sumSquares / <float>n);
}

isolated function assembleSemanticChunks(string[] sentences, int[] breakpoints, int minChunkSize) returns string[] {
    string[] chunks = [];
    int startIndex = 0;
    int n = sentences.length();
    foreach int breakpoint in breakpoints {
        // Boundary is "after sentence index `breakpoint`" so the next chunk starts at breakpoint + 1.
        int endIndex = breakpoint + 1;
        if endIndex > n {
            endIndex = n;
        }
        if endIndex <= startIndex {
            continue;
        }
        string candidate = joinSentences(sentences, startIndex, endIndex);
        if candidate.length() >= minChunkSize {
            chunks.push(candidate);
            startIndex = endIndex;
        }
    }
    if startIndex < n {
        string tail = joinSentences(sentences, startIndex, n);
        if chunks.length() == 0 {
            chunks.push(tail);
        } else if tail.length() < minChunkSize {
            // Append the short tail to the previous chunk so we honor minChunkSize.
            chunks[chunks.length() - 1] = chunks[chunks.length() - 1] + " " + tail;
        } else {
            chunks.push(tail);
        }
    }
    return chunks;
}

isolated function joinSentences(string[] sentences, int startIndex, int endIndex) returns string {
    string result = "";
    foreach int i in startIndex ..< endIndex {
        if result.length() > 0 {
            result += " ";
        }
        result += sentences[i];
    }
    return result;
}

isolated function buildSemanticChunk(TextDocument|TextChunk sourceDoc, string content, int index) returns TextChunk {
    Metadata existing = sourceDoc.metadata ?: {};
    Metadata metadata = existing.clone();
    metadata.index = index;
    return {content, metadata};
}

# Represents the available strategies for chunking a PDF document.
#
# `PDF_PAGE` preserves page boundaries (one chunk per page, recursively split
# only when an individual page exceeds `maxChunkSize`). The remaining
# strategies concatenate all pages first and then apply the chosen text
# strategy with recursive fallback to finer-grained units, matching
# `GenericRecursiveChunker`.
public enum PdfChunkStrategy {
    # One chunk per page. If a page exceeds `maxChunkSize`, it falls back to
    # PARAGRAPH, SENTENCE, WORD, then CHARACTER. Linked chunks share the same
    # `pageNumber` metadata and are connected via the `prev` field.
    PDF_PAGE,

    # Treat the entire extracted text as a single document and split using
    # the PARAGRAPH strategy with the standard recursive fallback.
    PDF_PARAGRAPH,

    # Split by sentences (with WORD/CHARACTER fallback).
    PDF_SENTENCE,

    # Split by words (with CHARACTER fallback).
    PDF_WORD,

    # Split by characters.
    PDF_CHARACTER
}

# Represents a PDF document chunker.
# Extracts text page-by-page from a PDF using Apache PDFBox, then chunks
# the resulting text using a configurable strategy. Emits per-chunk
# `pageNumber` and `totalPages` metadata when the `PDF_PAGE` strategy is
# used.
public isolated class PdfChunker {
    *Chunker;
    private final int maxChunkSize;
    private final int maxOverlapSize;
    private final PdfChunkStrategy strategy;
    private final boolean sortByPosition;
    private final string? password;

    # Initializes a new instance of the `PdfChunker`.
    #
    # + maxChunkSize - Maximum number of characters allowed per chunk
    # + maxOverlapSize - Maximum number of characters reused from the end of the previous
    # chunk when creating the next one
    # + strategy - The PDF chunking strategy to use. Defaults to `PDF_PAGE`.
    # + sortByPosition - When `true`, text is sorted left-to-right, top-to-bottom before
    # extraction. Recommended for multi-column and non-linearized PDFs.
    # + password - Password for encrypted PDFs. Set to `()` for unencrypted documents.
    public isolated function init(int maxChunkSize = 200, int maxOverlapSize = 40,
            PdfChunkStrategy strategy = PDF_PAGE,
            boolean sortByPosition = true,
            string? password = ()) {
        self.maxChunkSize = maxChunkSize;
        self.maxOverlapSize = maxOverlapSize;
        self.strategy = strategy;
        self.sortByPosition = sortByPosition;
        self.password = password;
    }

    # Chunks the provided document.
    # + document - The input document to be chunked. Must be a `BinaryDocument`,
    # a `FileDocument` whose content is a `byte[]`, or a `TextDocument`
    # (which is treated as already-extracted PDF text).
    # + return - An array of chunks, or an `ai:Error` if the chunking fails
    public isolated function chunk(Document document) returns Chunk[]|Error {
        return chunkPdfDocument(document, self.maxChunkSize, self.maxOverlapSize,
                self.strategy, self.sortByPosition, self.password);
    }
}

# Splits a PDF document into text chunks.
#
# The chunker accepts a `BinaryDocument`, a `FileDocument` with `byte[]`
# content, or a `TextDocument` (which is treated as already-extracted text
# and delegated to `chunkDocumentRecursively`).
#
# + document - The input PDF document
# + maxChunkSize - Maximum number of characters allowed per chunk
# + maxOverlapSize - Maximum number of characters reused from the end of the previous chunk
# + strategy - The PDF chunking strategy to use
# + sortByPosition - Whether to sort extracted text by visual position
# + password - Password for encrypted PDFs
# + return - An array of chunks, or an `ai:Error` if the chunking fails
public isolated function chunkPdfDocument(Document document,
        int maxChunkSize = 200, int maxOverlapSize = 40,
        PdfChunkStrategy strategy = PDF_PAGE,
        boolean sortByPosition = true,
        string? password = ()) returns Chunk[]|Error {
    if maxChunkSize <= 0 {
        return error Error("maxChunkSize must be greater than 0");
    }
    if maxOverlapSize < 0 {
        return error Error("maxOverlapSize must be non-negative");
    }
    if maxOverlapSize > maxChunkSize {
        return error Error("maxOverlapSize must be less than or equal to maxChunkSize");
    }
    if document is TextDocument {
        return chunkDocumentRecursively(document, maxChunkSize, maxOverlapSize, PARAGRAPH);
    }
    byte[] pdfBytes;
    if document is BinaryDocument {
        pdfBytes = document.content;
    } else if document is FileDocument {
        byte[]|Url|FileId fileContent = document.content;
        if fileContent is byte[] {
            pdfBytes = fileContent;
        } else {
            return error Error("PdfChunker only supports FileDocument with byte[] content");
        }
    } else {
        return error Error("PdfChunker only supports PDF binary/file documents");
    }
    return chunkPdfDocumentInner(document, pdfBytes, maxChunkSize, maxOverlapSize,
            strategy, sortByPosition, password ?: ());
}

isolated function chunkPdfDocumentInner(Document document, byte[] pdfBytes,
        int chunkSize, int overlapSize, PdfChunkStrategy strategy,
        boolean sortByPosition, string? password,
        typedesc<TextChunk> textChunkType = TextChunk) returns TextChunk[]|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.Chunkers",
    name: "chunkPdfDocument"
} external;
