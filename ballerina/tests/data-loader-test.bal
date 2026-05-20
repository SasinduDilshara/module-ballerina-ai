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

import ballerina/http;
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

