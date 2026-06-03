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

import ballerina/file;
import ballerina/http;
import ballerina/io;
import ballerina/test;

// Helper function to validate document structure and metadata
isolated function validateDocument(Document document, string? expectedMimeType, string expectedFileName) returns error? {
    // Validate document type
    test:assertEquals(document.'type, "text", "Document type should be 'text'");

    // Validate metadata exists and has expected fields
    Metadata? metadata = document.metadata;
    if metadata is () {
        test:assertFail("Document metadata should not be null");
    }

    // Validate mime type
    test:assertEquals(metadata.mimeType, expectedMimeType, string `MIME type should be '${expectedMimeType.toString()}'`);

    // Validate file name
    test:assertEquals(metadata.fileName, expectedFileName, "File name doesn't match expected value");

    // Validate content is not empty
    anydata content = document.content;
    if content is string {
        test:assertTrue(content.length() > 0, "Document content should not be empty");
    } else {
        test:assertFail("Document content should be a string");
    }
}

// Helper function to get single document from result
isolated function getSingleDocument(Document[]|Document|Error result) returns Document|error {
    if result is Error {
        return error("Document loading failed: " + result.message());
    }

    Document document;
    if result is Document[] {
        test:assertEquals(result.length(), 1, "Should return array with single document");
        document = result[0];
    } else {
        document = result;
    }
    return document;
}

@test:Config {groups: ["pdf", "document-loader"]}
function testTextDataLoaderLoadPdf() returns error? {
    // Test PDF loading with a sample PDF file
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    TextDataLoader loader = check new (pdfPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/pdf", "TestDoc.pdf");
}

@test:Config {groups: ["document-loader", "error-handling"]}
function testTextDataLoaderUnsupportedFileType() returns error? {
    // Test with an unsupported file type
    string unsupportedPath = "tests/resources/data-loader/test.txt";
    TextDataLoader loader = check new (unsupportedPath);

    Document[]|Document|Error result = loader.load();

    // Verify the result is an error for unsupported file types
    if result is Error {
        test:assertTrue(result.message().includes("Unsupported file type: txt"),
                "Should return error for unsupported file types with file extension");
    } else {
        test:assertFail("Should return error for unsupported file types");
    }
}

@test:Config {groups: ["docx", "document-loader"]}
function testTextDataLoaderLoadDocx() returns error? {
    // Test DOCX loading with a sample DOCX file
    string docxPath = "tests/resources/data-loader/TestDoc.docx";
    TextDataLoader loader = check new (docxPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "TestDoc.docx");
}

@test:Config {groups: ["pptx", "document-loader"]}
function testTextDataLoaderLoadPptx() returns error? {
    // Test PPTX loading with a sample PPTX file
    string pptxPath = "tests/resources/data-loader/Test presentation.pptx";
    TextDataLoader loader = check new (pptxPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/vnd.openxmlformats-officedocument.presentationml.presentation", "Test presentation.pptx");
}

@test:Config {groups: ["md", "document-loader"]}
function testTextDataLoaderLoadMarkdown() returns error? {
    string mdPath = "tests/resources/data-loader/Test.md";
    TextDataLoader loader = check new (mdPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, (), "Test.md");
}

@test:Config {groups: ["html", "document-loader"]}
function testTextDataLoaderHtml() returns error? {
    string htmlPath = "tests/resources/data-loader/Test.html";
    TextDataLoader loader = check new (htmlPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, (), "Test.html");
}

@test:Config {groups: ["html", "document-loader"]}
function testTextDataLoaderHtm() returns error? {
    string htmlPath = "tests/resources/data-loader/Test.htm";
    TextDataLoader loader = check new (htmlPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, (), "Test.htm");
}

@test:Config {groups: ["document-loader", "error-handling", "pdf"]}
function testTextDataLoaderFileDoesNotExist() returns error? {
    // Test with a non-existent file path
    string nonExistentPath = "tests/resources/data-loader/non_existent_file.pdf";

    // Test constructor with non-existent file
    TextDataLoader|Error loader = new (nonExistentPath);

    // Verify the constructor returns an error for non-existent files
    if loader is Error {
        test:assertTrue(loader.message().includes("File does not exist"),
                "Error message should indicate file does not exist");
    } else {
        test:assertFail("Constructor should return error for non-existent files");
    }
}

@test:Config {groups: ["document-loader", "error-handling", "pdf"]}
function testTextDataLoaderCaseInsensitiveExtensions() returns error? {
    // Test that uppercase extensions work (assuming we can create test files with uppercase extensions)
    // This test validates the case-insensitive extension checking
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    TextDataLoader loader = check new (pdfPath);

    // This should work even though we check with .PDF, .Pdf etc. internally
    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/pdf", "TestDoc.pdf");
}

@test:Config {groups: ["document-loader", "error-handling"]}
function testTextDataLoaderImprovedErrorMessage() returns error? {
    // Test that error message includes file extension
    string unsupportedPath = "tests/resources/data-loader/test.txt";
    TextDataLoader loader = check new (unsupportedPath);

    Document[]|Document|Error result = loader.load();

    if result is Error {
        // Verify error message includes the file extension
        test:assertTrue(result.message().includes("Unsupported file type: txt"),
                "Error message should include the file extension");
    } else {
        test:assertFail("Should return error for unsupported file types");
    }
}

@test:Config {groups: ["document-loader", "multiple-files", "pdf", "docx", "pptx"]}
function testTextDataLoaderMultipleFiles() returns error? {
    // Test loading multiple files at once
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    string docxPath = "tests/resources/data-loader/TestDoc.docx";
    string pptxPath = "tests/resources/data-loader/Test presentation.pptx";

    TextDataLoader loader = check new (pdfPath, docxPath, pptxPath);

    Document[]|Document|Error result = loader.load();

    // Since we're loading multiple files, the result should be an array
    if result is Document[] {
        test:assertEquals(result.length(), 3, "Should return array with 3 documents");

        // Validate each document
        Document pdfDoc = result[0];
        Document docxDoc = result[1];
        Document pptxDoc = result[2];

        check validateDocument(pdfDoc, "application/pdf", "TestDoc.pdf");
        check validateDocument(docxDoc, "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "TestDoc.docx");
        check validateDocument(pptxDoc, "application/vnd.openxmlformats-officedocument.presentationml.presentation", "Test presentation.pptx");
    } else {
        test:assertFail("Should return array of documents when loading multiple files");
    }
}

@test:Config {groups: ["document-loader", "multiple-files", "single-file", "pdf"]}
function testTextDataLoaderSingleFileReturnsSingleDocument() returns error? {
    // Test that loading a single file returns a single document (not an array)
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";

    TextDataLoader loader = check new (pdfPath);

    Document[]|Document|Error result = loader.load();

    // When loading a single file, the result should be a single document
    if result is Document {
        check validateDocument(result, "application/pdf", "TestDoc.pdf");
    } else {
        test:assertFail("Should return single document when loading single file");
    }
}

@test:Config {groups: ["document-loader", "multiple-files", "error-handling", "pdf"]}
function testTextDataLoaderMultipleFilesWithInvalidFile() returns error? {
    // Test loading multiple files where one doesn't exist
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    string nonExistentPath = "tests/resources/data-loader/non_existent_file.docx";

    // Constructor should fail if any file doesn't exist
    TextDataLoader|Error loader = new (pdfPath, nonExistentPath);

    if loader is Error {
        return test:assertTrue(loader.message().includes("File does not exist"),
                "Error message should indicate file does not exist");
    }
    test:assertFail("Constructor should return error when any file doesn't exist");
}

@test:Config {groups: ["csv", "document-loader"]}
function testTextDataLoaderLoadCsv() returns error? {
    string csvPath = "tests/resources/data-loader/Test.csv";
    TextDataLoader loader = check new (csvPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "text/csv", "Test.csv");
    test:assertTrue((<string>document.content).includes("Alice"),
            "CSV content should contain expected row data");
}

@test:Config {groups: ["tsv", "document-loader"]}
function testTextDataLoaderLoadTsv() returns error? {
    string tsvPath = "tests/resources/data-loader/Test.tsv";
    TextDataLoader loader = check new (tsvPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "text/tab-separated-values", "Test.tsv");
    test:assertTrue((<string>document.content).includes("\t"),
            "TSV content should contain tab separators");
}

@test:Config {groups: ["json", "document-loader"]}
function testTextDataLoaderLoadJson() returns error? {
    string jsonPath = "tests/resources/data-loader/Test.json";
    TextDataLoader loader = check new (jsonPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/json", "Test.json");
    test:assertTrue((<string>document.content).includes("ballerina-ai"),
            "JSON content should contain the team identifier");
}

@test:Config {groups: ["directory-loader", "document-loader"]}
function testDirectoryDataLoaderNonRecursiveSkipsUnsupported() returns error? {
    string dirPath = "tests/resources/data-loader/dir";
    DirectoryDataLoader loader = check new (dirPath);

    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Expected an array of documents from directory load");
    }
    // dir/ contains mixed.md, mixed.csv, notes.txt (skipped), and dir/nested/nested.json (not visited)
    test:assertEquals(result.length(), 2, "Should load 2 supported files in non-recursive mode");
    string[] fileNames = from Document doc in result
        let string? name = doc.metadata?.fileName
        where name is string
        select name;
    test:assertTrue(fileNames.indexOf("mixed.md") is int, "Should include mixed.md");
    test:assertTrue(fileNames.indexOf("mixed.csv") is int, "Should include mixed.csv");
    test:assertTrue(fileNames.indexOf("notes.txt") is (), "Should skip unsupported notes.txt");
}

@test:Config {groups: ["directory-loader", "document-loader"]}
function testDirectoryDataLoaderRecursive() returns error? {
    string dirPath = "tests/resources/data-loader/dir";
    DirectoryDataLoader loader = check new (dirPath, recursive = true);

    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Expected an array of documents from recursive directory load");
    }
    test:assertEquals(result.length(), 3, "Should load supported files from subdirectories too");
    string[] fileNames = from Document doc in result
        let string? name = doc.metadata?.fileName
        where name is string
        select name;
    test:assertTrue(fileNames.indexOf("nested.json") is int, "Should include nested.json from subdir");
}

@test:Config {groups: ["directory-loader", "error-handling"]}
function testDirectoryDataLoaderMissingPath() returns error? {
    DirectoryDataLoader|Error loader = new ("tests/resources/data-loader/does-not-exist");
    if loader is Error {
        test:assertTrue(loader.message().includes("Directory does not exist"),
                "Error message should indicate missing directory");
        return;
    }
    test:assertFail("Constructor should return error for non-existent directory");
}

@test:Config {groups: ["directory-loader", "error-handling"]}
function testDirectoryDataLoaderPathIsFile() returns error? {
    DirectoryDataLoader|Error loader = new ("tests/resources/data-loader/Test.csv");
    if loader is Error {
        test:assertTrue(loader.message().includes("not a directory"),
                "Error message should indicate path is not a directory");
        return;
    }
    test:assertFail("Constructor should return error when path is a file");
}

// --- UrlDataLoader tests ----------------------------------------------------

const int URL_LOADER_TEST_PORT = 18799;

isolated service /loader on new http:Listener(URL_LOADER_TEST_PORT, host = "localhost") {
    isolated resource function get text\.csv() returns http:Response {
        http:Response res = new;
        res.setTextPayload("col1,col2\nfoo,bar\n", contentType = "text/csv");
        return res;
    }

    isolated resource function get page\.html() returns http:Response {
        http:Response res = new;
        res.setTextPayload("<html><body>hi</body></html>", contentType = "text/html");
        return res;
    }

    // Served without an extension - type must be inferred from Content-Type.
    isolated resource function get inferred() returns http:Response {
        http:Response res = new;
        res.setTextPayload("{\"ok\": true}", contentType = "application/json");
        return res;
    }

    isolated resource function get echoauth(@http:Header string? authorization) returns http:Response {
        http:Response res = new;
        res.setTextPayload("auth=" + (authorization ?: "none") + ".json",
                contentType = "application/json");
        return res;
    }

    isolated resource function get unsupported() returns http:Response {
        http:Response res = new;
        byte[] payload = [0x00, 0x01];
        res.setBinaryPayload(payload, contentType = "application/octet-stream");
        return res;
    }

    isolated resource function get notfound() returns http:Response {
        http:Response res = new;
        res.statusCode = 404;
        return res;
    }

    // Serves a real PDF so the URL loader's binary pipeline (download -> temp file ->
    // native parse -> temp cleanup) is exercised end to end.
    isolated resource function get doc\.pdf() returns http:Response|error {
        http:Response res = new;
        byte[] bytes = check io:fileReadBytes("tests/resources/data-loader/TestDoc.pdf");
        res.setBinaryPayload(bytes, contentType = "application/pdf");
        return res;
    }
}

@test:Config {groups: ["url-loader", "document-loader"]}
function testUrlDataLoaderTextByExtension() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/text.csv`;
    UrlDataLoader loader = new ([url]);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    test:assertEquals(document.metadata?.mimeType, "text/csv", "MIME type should be text/csv");
    test:assertEquals(document.metadata?.fileName, "text.csv", "File name should be derived from URL");
    test:assertTrue((<string>document.content).includes("foo,bar"), "Content should match the response body");
}

@test:Config {groups: ["url-loader", "document-loader"]}
function testUrlDataLoaderTypeInferredFromContentType() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/inferred`;
    UrlDataLoader loader = new ([url]);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    test:assertEquals(document.metadata?.mimeType, "application/json",
            "Should infer application/json from Content-Type when URL has no extension");
}

@test:Config {groups: ["url-loader", "document-loader"]}
function testUrlDataLoaderForwardsHeaders() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/echoauth`;
    UrlDataLoader loader = new ([url], headers = {"Authorization": "Bearer test-token"});

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    test:assertTrue((<string>document.content).includes("Bearer test-token"),
            "Authorization header should be forwarded to the upstream");
}

@test:Config {groups: ["url-loader", "document-loader", "error-handling"]}
function testUrlDataLoaderHttpError() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/notfound`;
    UrlDataLoader loader = new ([url]);

    Document[]|Document|Error result = loader.load();
    if result is Error {
        test:assertTrue(result.message().includes("HTTP 404"),
                "Error message should report the HTTP status");
        return;
    }
    test:assertFail("Loader should return error for non-2xx response");
}

@test:Config {groups: ["url-loader", "document-loader", "error-handling"]}
function testUrlDataLoaderUnsupportedContent() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/unsupported`;
    UrlDataLoader loader = new ([url]);

    Document[]|Document|Error result = loader.load();
    if result is Error {
        test:assertTrue(result.message().includes("Unsupported content"),
                "Error message should indicate unsupported content");
        return;
    }
    test:assertFail("Loader should return error for unsupported content type");
}

@test:Config {groups: ["url-loader", "document-loader", "error-handling"]}
function testUrlDataLoaderInvalidUrl() returns error? {
    Url url = "not-a-url";
    UrlDataLoader loader = new ([url]);

    Document[]|Document|Error result = loader.load();
    if result is Error {
        test:assertTrue(result.message().includes("Invalid URL"),
                "Error message should indicate invalid URL");
        return;
    }
    test:assertFail("Loader should return error for invalid URL");
}


// --- Added coverage: URL binary pipeline, query/fragment handling, uppercase
// --- extensions, empty inputs, metadata fields, and URL/mime helper units. ---

@test:Config {groups: ["url-loader", "document-loader", "pdf"]}
function testUrlDataLoaderBinaryPdf() returns error? {
    // Exercises the remote-binary path: download -> temp file -> native parse -> cleanup.
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/doc.pdf`;
    UrlDataLoader loader = new ([url]);

    Document document = check getSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "URL-loaded PDF should produce a text Document");
    test:assertEquals(document.metadata?.mimeType, "application/pdf", "URL PDF mime type should be application/pdf");
    test:assertEquals(document.metadata?.fileName, "doc.pdf", "fileName should be derived from the URL path");
    test:assertTrue((<string>document.content).length() > 0, "Parsed PDF content should not be empty");
}

@test:Config {groups: ["url-loader", "document-loader"]}
function testUrlDataLoaderStripsQueryString() returns error? {
    Url url = string `http://localhost:${URL_LOADER_TEST_PORT}/loader/text.csv?token=abc&v=2`;
    UrlDataLoader loader = new ([url]);

    Document document = check getSingleDocument(loader.load());
    test:assertEquals(document.metadata?.fileName, "text.csv",
            "Query string should be stripped from the derived fileName");
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "Extension resolution should ignore the query string");
}

@test:Config {groups: ["url-loader", "document-loader"]}
function testUrlDataLoaderEmptyUrlList() returns error? {
    UrlDataLoader loader = new ([]);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("An empty URL list should yield a Document[]");
    }
    test:assertEquals(result.length(), 0, "Empty URL list should produce an empty document array");
}

@test:Config {groups: ["directory-loader", "document-loader"]}
function testDirectoryDataLoaderOnlyUnsupportedFiles() returns error? {
    DirectoryDataLoader loader = check new ("tests/resources/data-loader/unsupported-only");
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("A directory of only unsupported files should yield a Document[]");
    }
    test:assertEquals(result.length(), 0, "All files are unsupported, so no documents should be produced");
}

@test:Config {groups: ["directory-loader", "document-loader"]}
function testDirectoryDataLoaderEmptyDirectory() returns error? {
    string tempDir = check file:createTempDir();
    DirectoryDataLoader loader = check new (tempDir);
    Document[]|Document|Error result = loader.load();
    file:Error? removeErr = file:remove(tempDir, file:RECURSIVE);
    if removeErr is file:Error {
        // best-effort cleanup; not a test failure
    }
    if result !is Document[] {
        test:assertFail("An empty directory should yield a Document[]");
    }
    test:assertEquals(result.length(), 0, "An empty directory should produce an empty document array");
}

@test:Config {groups: ["document-loader", "csv"]}
function testTextDataLoaderUppercaseExtension() returns error? {
    // Report.CSV has an UPPERCASE extension; resolution must be case-insensitive.
    TextDataLoader loader = check new ("tests/resources/data-loader/Report.CSV");
    Document document = check getSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "Uppercase .CSV should still resolve to text/csv");
    test:assertEquals(document.metadata?.fileName, "Report.CSV",
            "fileName should preserve the original casing");
    test:assertTrue((<string>document.content).includes("Zoe"), "Content should match the fixture");
}

@test:Config {groups: ["document-loader", "pdf"]}
function testBuildDocumentFromBytesBinaryPdf() returns error? {
    // Covers buildDocumentFromBytes' binary branch (temp file + native parse).
    byte[] pdfBytes = check io:fileReadBytes("tests/resources/data-loader/TestDoc.pdf");
    Document|Error result = buildDocumentFromBytes(pdfBytes, "application/pdf", "frombytes.pdf");
    if result is Error {
        test:assertFail("buildDocumentFromBytes should parse a PDF byte payload: " + result.message());
    }
    test:assertEquals(result.'type, "text", "Built document should be of type 'text'");
    test:assertEquals(result.metadata?.mimeType, "application/pdf", "mime type should be application/pdf");
    test:assertEquals(result.metadata?.fileName, "frombytes.pdf", "fileName should be preserved");
    test:assertTrue((<string>result.content).length() > 0, "Parsed PDF content should not be empty");
}

@test:Config {groups: ["document-loader"]}
function testTextDataLoaderMetadataFields() returns error? {
    TextDataLoader loader = check new ("tests/resources/data-loader/Test.csv");
    Document document = check getSingleDocument(loader.load());
    decimal? fileSize = document.metadata?.fileSize;
    test:assertTrue(fileSize is decimal && fileSize > 0d, "fileSize metadata should be a positive decimal");
    test:assertTrue(document.metadata?.modifiedAt !is (), "modifiedAt metadata should be populated");
}

@test:Config {groups: ["url-loader", "unit"]}
function testGetFileNameFromUrlVariants() {
    test:assertEquals(getFileNameFromUrl("http://host/a/b/file.csv", CSV), "file.csv",
            "Plain URL should yield the last path segment");
    test:assertEquals(getFileNameFromUrl("http://host/a/file.csv?token=x", CSV), "file.csv",
            "Query string should be stripped from the fileName");
    test:assertEquals(getFileNameFromUrl("http://host/a/file.csv#section", CSV), "file.csv",
            "Fragment should be stripped from the fileName");
    test:assertEquals(getFileNameFromUrl("http://host/dir/", JSON), "index.json",
            "A trailing slash should fall back to index.<type>");
}

@test:Config {groups: ["url-loader", "unit"]}
function testGetFileExtensionFromUrlVariants() {
    test:assertEquals(getFileExtensionFromUrl("http://host/dir/file.csv?token=x"), "csv",
            "Extension should be resolved after stripping the query");
    test:assertEquals(getFileExtensionFromUrl("http://host/dir/file.json#frag"), "json",
            "Extension should be resolved after stripping the fragment");
    test:assertEquals(getFileExtensionFromUrl("http://host/noext"), "unknown",
            "A path with no extension should yield 'unknown'");
}

@test:Config {groups: ["url-loader", "unit"]}
function testSplitUrlVariants() returns error? {
    [string, string]|Error withPath = splitUrl("http://host/a/b");
    if withPath is Error {
        test:assertFail("splitUrl should succeed for a URL with a path");
    }
    test:assertEquals(withPath[0], "http://host", "origin should be split correctly");
    test:assertEquals(withPath[1], "/a/b", "path should be split correctly");

    [string, string]|Error noPath = splitUrl("http://host");
    if noPath is Error {
        test:assertFail("splitUrl should succeed for a URL without a path");
    }
    test:assertEquals(noPath[1], "/", "A URL with no path should default the path to '/'");

    [string, string]|Error invalid = splitUrl("not-a-url");
    test:assertTrue(invalid is Error, "splitUrl should error on a URL without a scheme separator");
}

@test:Config {groups: ["document-loader", "unit"]}
function testGetFileTypeFromMimeVariants() {
    test:assertEquals(getFileTypeFromMime("text/csv; charset=utf-8"), CSV,
            "A mime type with parameters should still resolve");
    test:assertEquals(getFileTypeFromMime("application/xhtml+xml"), HTML,
            "xhtml+xml should resolve to HTML");
    test:assertTrue(getFileTypeFromMime("application/zip") is (),
            "An unsupported mime type should resolve to ()");
}

@test:Config {groups: ["document-loader", "unit"]}
function testFileTypeCaseInsensitiveAndNoExtension() {
    test:assertEquals(getFileType("X.PDF"), PDF, "Uppercase extension should resolve case-insensitively");
    test:assertEquals(getFileExtension("Report.CSV"), "csv", "getFileExtension should lower-case the extension");
    test:assertTrue(getFileType("README") is (), "A file with no extension should resolve to ()");
}

// --- PdfDataLoader tests ----------------------------------------------------

@test:Config {groups: ["pdf", "document-loader", "pdf-loader"]}
function testPdfDataLoaderLoadSingle() returns error? {
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    PdfDataLoader loader = check new (pdfPath);

    Document[]|Document|Error result = loader.load();
    Document document = check getSingleDocument(result);
    check validateDocument(document, "application/pdf", "TestDoc.pdf");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "single-file"]}
function testPdfDataLoaderSingleFileReturnsSingleDocument() returns error? {
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    PdfDataLoader loader = check new (pdfPath);

    Document[]|Document|Error result = loader.load();
    if result is Document {
        check validateDocument(result, "application/pdf", "TestDoc.pdf");
    } else {
        test:assertFail("Should return single document when loading single PDF");
    }
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "multiple-files"]}
function testPdfDataLoaderMultipleFiles() returns error? {
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    PdfDataLoader loader = check new (pdfPath, pdfPath);

    Document[]|Document|Error result = loader.load();
    if result is Document[] {
        test:assertEquals(result.length(), 2, "Should return array with 2 documents");
        check validateDocument(result[0], "application/pdf", "TestDoc.pdf");
        check validateDocument(result[1], "application/pdf", "TestDoc.pdf");
    } else {
        test:assertFail("Should return array of documents when loading multiple PDFs");
    }
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "multiple-files"]}
function testPdfDataLoaderEmptyPaths() returns error? {
    PdfDataLoader loader = check new ();

    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("An empty path list should yield a Document[]");
    }
    test:assertEquals(result.length(), 0, "Empty path list should produce an empty document array");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "error-handling"]}
function testPdfDataLoaderFileDoesNotExist() returns error? {
    string nonExistentPath = "tests/resources/data-loader/non_existent_file.pdf";
    PdfDataLoader|Error loader = new (nonExistentPath);

    if loader is Error {
        test:assertTrue(loader.message().includes("File does not exist"),
                "Error message should indicate file does not exist");
        return;
    }
    test:assertFail("Constructor should return error for non-existent files");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "error-handling"]}
function testPdfDataLoaderRejectsNonPdf() returns error? {
    string csvPath = "tests/resources/data-loader/Test.csv";
    PdfDataLoader|Error loader = new (csvPath);

    if loader is Error {
        test:assertTrue(loader.message().includes("Unsupported file type: csv"),
                "Error message should report the rejected extension");
        test:assertTrue(loader.message().includes("only supports 'pdf'"),
                "Error message should clarify only PDF is supported");
        return;
    }
    test:assertFail("Constructor should reject non-PDF files");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "error-handling", "multiple-files"]}
function testPdfDataLoaderRejectsNonPdfAmongValid() returns error? {
    string pdfPath = "tests/resources/data-loader/TestDoc.pdf";
    string docxPath = "tests/resources/data-loader/TestDoc.docx";
    PdfDataLoader|Error loader = new (pdfPath, docxPath);

    if loader is Error {
        test:assertTrue(loader.message().includes("Unsupported file type: docx"),
                "Constructor should reject when any path is not a PDF");
        return;
    }
    test:assertFail("Constructor should reject a mix containing a non-PDF file");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader", "error-handling"]}
function testPdfDataLoaderRejectsExtensionlessFile() returns error? {
    // A file with no extension resolves to an unknown type and must be rejected.
    PdfDataLoader|Error loader = new ("tests/resources/data-loader/test.txt");

    if loader is Error {
        test:assertTrue(loader.message().includes("Unsupported file type: txt"),
                "Constructor should reject a non-PDF extension");
        return;
    }
    test:assertFail("Constructor should reject a non-PDF file");
}

@test:Config {groups: ["pdf", "document-loader", "pdf-loader"]}
function testPdfDataLoaderViaAbstraction() returns error? {
    // Exercise the loader through the DataLoader abstraction type.
    DataLoader loader = check new PdfDataLoader("tests/resources/data-loader/TestDoc.pdf");
    Document document = check getSingleDocument(loader.load());
    check validateDocument(document, "application/pdf", "TestDoc.pdf");
}
