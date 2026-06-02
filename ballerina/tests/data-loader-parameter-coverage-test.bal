// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
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

// EACH-VALUE (1-wise) parameter-coverage tests for the data loaders.
//
// Each test varies exactly ONE constructor parameter (or one behavioral input
// variant) while holding every other input at a sensible default. The intent is
// 1-wise coverage: every distinct value of every parameter -- and every error
// branch -- appears in at least one test, WITHOUT a Cartesian explosion.
//
// This file is part of the same test module as `data-loader-test.bal` and
// `data-loader-abstraction-test.bal`. The following module-level declarations
// are ALREADY IN SCOPE and are reused here (never redeclared):
//   - the mock `http:Listener` service on `ABSTRACTION_MOCK_PORT` (18900)
//   - consts `ABSTRACTION_MOCK_PORT`, `ABSTRACTION_RESOURCE_DIR`
//   - helpers `abstractionSingleDocument`, `abstractionTextContent`
//
// All new function names are prefixed `testParamDataLoader`.

import ballerina/test;

// ===========================================================================
// TextDataLoader -- variadic `paths` count + per-extension coverage.
// Local fixtures, runs OFFLINE => group "easy".
// ===========================================================================

// `paths` variadic: ZERO arguments.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextZeroPaths() returns error? {
    DataLoader loader = check new TextDataLoader();
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("TextDataLoader with zero paths must return a Document[]");
    }
    test:assertEquals(result.length(), 0, "Zero paths must yield an empty document array");
}

// `paths` variadic: exactly ONE argument -- also covers the `pdf` extension.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextOnePathPdf() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf");
    Document[]|Document|Error result = loader.load();
    if result !is Document {
        test:assertFail("A single path must yield a single Document, not an array");
    }
    test:assertEquals(result.metadata?.mimeType, "application/pdf",
            "pdf extension should resolve to application/pdf");
}

// `paths` variadic: SEVERAL arguments.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextSeveralPaths() returns error? {
    DataLoader loader = check new TextDataLoader(
        ABSTRACTION_RESOURCE_DIR + "/Test.csv",
        ABSTRACTION_RESOURCE_DIR + "/Test.tsv",
        ABSTRACTION_RESOURCE_DIR + "/Test.json",
        ABSTRACTION_RESOURCE_DIR + "/Test.md");
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Several paths must yield a Document[]");
    }
    test:assertEquals(result.length(), 4, "Four paths must yield four documents");
}

// Extension coverage: `docx`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionDocx() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.docx");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "docx extension should resolve to the OOXML wordprocessing mime type");
}

// Extension coverage: `pptx`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionPptx() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test presentation.pptx");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType,
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "pptx extension should resolve to the OOXML presentation mime type");
}

// Extension coverage: `html`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionHtml() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.html");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "html should load as a text Document");
    // readTextDocument carries no mime type for html.
    test:assertEquals(document.metadata?.fileName, "Test.html", "html fileName should be Test.html");
}

// Extension coverage: `htm`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionHtm() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.htm");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "htm should load as a text Document");
    test:assertEquals(document.metadata?.fileName, "Test.htm", "htm fileName should be Test.htm");
}

// Extension coverage: `md`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionMarkdown() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.md");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "md should load as a text Document");
    test:assertEquals(document.metadata?.mimeType, (), "md document should carry no mime type");
}

// Extension coverage: `csv`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionCsv() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "csv extension should resolve to text/csv");
}

// Extension coverage: `tsv`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionTsv() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.tsv");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/tab-separated-values",
            "tsv extension should resolve to text/tab-separated-values");
}

// Extension coverage: `json`.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextExtensionJson() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.json");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "application/json",
            "json extension should resolve to application/json");
}

// Extension coverage: an UNSUPPORTED extension (.txt) -- init succeeds, load fails.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextUnsupportedExtension() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/test.txt");
    Document[]|Document|Error result = loader.load();
    if result !is Error {
        test:assertFail("Loading a .txt file should produce an Error");
    }
    test:assertTrue(result.message().includes("Unsupported file type"),
            "Load error should report the unsupported file type");
}

// Path variant: a MISSING path -- init itself fails.
@test:Config {groups: ["easy"]}
function testParamDataLoaderTextMissingPath() returns error? {
    TextDataLoader|Error loader = new (ABSTRACTION_RESOURCE_DIR + "/no-such.pdf");
    if loader !is Error {
        test:assertFail("TextDataLoader init should fail for a missing path");
    }
    test:assertTrue(loader.message().includes("File does not exist"),
            "Init error should report that the file does not exist");
}

// ===========================================================================
// DirectoryDataLoader -- `recursive` true/false + path-error variants.
// Local fixtures, runs OFFLINE => group "easy".
// ===========================================================================

// `recursive` parameter value: FALSE (the default).
@test:Config {groups: ["easy"]}
function testParamDataLoaderDirectoryRecursiveFalse() returns error? {
    DataLoader loader = check new DirectoryDataLoader(ABSTRACTION_RESOURCE_DIR + "/dir", recursive = false);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Non-recursive directory load should return a Document[]");
    }
    // dir/ has mixed.md + mixed.csv supported; notes.txt skipped; nested/ not visited.
    test:assertEquals(result.length(), 2, "recursive=false should find only the 2 top-level files");
}

// `recursive` parameter value: TRUE.
@test:Config {groups: ["easy"]}
function testParamDataLoaderDirectoryRecursiveTrue() returns error? {
    DataLoader loader = check new DirectoryDataLoader(ABSTRACTION_RESOURCE_DIR + "/dir", recursive = true);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Recursive directory load should return a Document[]");
    }
    // Recursive load additionally picks up nested/nested.json.
    test:assertEquals(result.length(), 3, "recursive=true should also find the nested file");
}

// `path` variant: a NON-EXISTENT directory -- init fails.
@test:Config {groups: ["easy"]}
function testParamDataLoaderDirectoryMissing() returns error? {
    DirectoryDataLoader|Error loader = new (ABSTRACTION_RESOURCE_DIR + "/no-such-dir");
    if loader !is Error {
        test:assertFail("DirectoryDataLoader init should fail for a missing directory");
    }
    test:assertTrue(loader.message().includes("Directory does not exist"),
            "Init error should report that the directory does not exist");
}

// `path` variant: a path that is a FILE, not a directory -- init fails.
@test:Config {groups: ["easy"]}
function testParamDataLoaderDirectoryPathIsFile() returns error? {
    DirectoryDataLoader|Error loader = new (ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    if loader !is Error {
        test:assertFail("DirectoryDataLoader init should fail when the path is a file");
    }
    test:assertTrue(loader.message().includes("not a directory"),
            "Init error should report that the path is not a directory");
}

// ===========================================================================
// UrlDataLoader -- `headers` empty/non-empty, `urls` count, type resolution,
// error and malformed-URL variants. Runs against the in-scope mock => "medium".
// ===========================================================================

// `headers` parameter value: EMPTY (the default) + single-URL list +
// type-by-extension resolution.
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlHeadersEmpty() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([<Url>(base + "/data.csv")]);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "URL loader with empty headers should resolve csv by extension");
}

// `headers` parameter value: NON-EMPTY.
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlHeadersNonEmpty() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader(
        [<Url>(base + "/data.csv")],
        headers = {"Authorization": "Bearer paramcov-token", "X-Trace": "paramcov"});
    // Non-empty headers must not break a load against an endpoint that ignores them.
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "URL loader with non-empty headers should still resolve the document");
}

// `urls` list size: exactly ONE url.
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlSingleUrl() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([<Url>(base + "/data.csv")]);
    Document[]|Document|Error result = loader.load();
    if result !is Document {
        test:assertFail("A single URL must yield a single Document, not an array");
    }
    test:assertEquals(result.'type, "text", "Single-URL load should produce a text Document");
}

// `urls` list size: SEVERAL urls.
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlSeveralUrls() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([
        <Url>(base + "/data.csv"),
        <Url>(base + "/inferred"),
        <Url>(base + "/data.csv")
    ]);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Several URLs must yield a Document[]");
    }
    test:assertEquals(result.length(), 3, "Three URLs must yield three documents");
}

// Type-resolution variant: type inferred from the URL path EXTENSION.
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlTypeByExtension() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([<Url>(base + "/data.csv")]);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.fileName, "data.csv",
            "fileName should be derived from the URL path");
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "csv type should be resolved from the URL extension");
}

// Type-resolution variant: type inferred from the response CONTENT-TYPE header
// (the URL path `/inferred` carries no extension).
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlTypeByContentType() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([<Url>(base + "/inferred")]);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "application/json",
            "json type should be resolved from the Content-Type header");
}

// Behavioral variant: an HTTP error response (404).
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlHttpError() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;
    DataLoader loader = new UrlDataLoader([<Url>(base + "/missing")]);
    Document[]|Document|Error result = loader.load();
    if result !is Error {
        test:assertFail("URL loader should error on a 404 response");
    }
    test:assertTrue(result.message().includes("HTTP 404"),
            "URL loader error should report the HTTP 404 status");
}

// Behavioral variant: a MALFORMED URL (no scheme separator).
@test:Config {groups: ["medium"]}
function testParamDataLoaderUrlMalformed() returns error? {
    DataLoader loader = new UrlDataLoader([<Url>"not-a-valid-url"]);
    Document[]|Document|Error result = loader.load();
    if result !is Error {
        test:assertFail("URL loader should error on a malformed URL");
    }
    test:assertTrue(result.message().includes("Invalid URL"),
            "Malformed URL should produce an 'Invalid URL' error");
}

// ===========================================================================
// buildDocumentFromBytes -- internal helper, mime/extension resolution variants.
// Pure in-memory, runs OFFLINE => group "easy".
// ===========================================================================

// Resolution variant: type resolved from the explicit MIME type.
@test:Config {groups: ["easy"]}
function testParamDataLoaderBuildBytesByMimeType() returns error? {
    byte[] bytes = "name,role\nAda,Engineer\n".toBytes();
    Document document = check buildDocumentFromBytes(bytes, "text/csv", "report");
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "csv mime type should drive the resolution");
    test:assertEquals(document.metadata?.fileName, "report",
            "fileName should be preserved verbatim");
}

// Resolution variant: MIME unknown -> fall back to the fileName EXTENSION.
@test:Config {groups: ["easy"]}
function testParamDataLoaderBuildBytesByExtensionFallback() returns error? {
    byte[] bytes = "{\"k\": \"v\"}".toBytes();
    // Empty mime forces the extension-based fallback path.
    Document document = check buildDocumentFromBytes(bytes, "", "payload.json");
    test:assertEquals(document.metadata?.mimeType, "application/json",
            "json should be resolved from the fileName extension when mime is empty");
}

// Resolution variant: NEITHER mime nor extension is supported -> Error.
@test:Config {groups: ["easy"]}
function testParamDataLoaderBuildBytesUnsupported() returns error? {
    byte[] bytes = [0x00, 0x01, 0x02];
    Document|Error result = buildDocumentFromBytes(bytes, "application/octet-stream", "blob.bin");
    if result !is Error {
        test:assertFail("buildDocumentFromBytes should error on unsupported content");
    }
    test:assertTrue(result.message().includes("Unsupported content"),
            "Error should report that the content is unsupported");
}
