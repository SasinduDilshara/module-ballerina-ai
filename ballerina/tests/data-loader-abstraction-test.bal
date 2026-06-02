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

// Abstraction-focused tests for the data loaders. Every loader under test is
// declared through the `DataLoader` abstraction type. These tests are
// independent of `data-loader-test.bal`; all function names are prefixed with
// `testDataLoaderAbstraction` to avoid collisions.

import ballerina/http;
import ballerina/test;

// Configurable bound for the severe-level volume loop.
configurable int severeBatchSize = 8;

// Free port for the in-process cloud/url mock service.
const int ABSTRACTION_MOCK_PORT = 18900;

const string ABSTRACTION_RESOURCE_DIR = "tests/resources/data-loader";

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

// Coerces a load result to exactly one `Document`, failing the test otherwise.
isolated function abstractionSingleDocument(Document[]|Document|Error result) returns Document|error {
    if result is Error {
        return error("Document loading failed: " + result.message());
    }
    if result is Document[] {
        test:assertEquals(result.length(), 1, "Expected exactly one document in the array");
        return result[0];
    }
    return result;
}

// Reads the string content of a Document, failing the test if it is not a string.
isolated function abstractionTextContent(Document document) returns string|error {
    anydata content = document.content;
    if content is string {
        return content;
    }
    return error("Document content is not a string");
}

// ===========================================================================
// EASY (5)
// ===========================================================================

@test:Config {groups: ["easy"]}
function testDataLoaderAbstractionTextLoaderCsvSingleDocument() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    Document[]|Document|Error result = loader.load();
    if result !is Document {
        test:assertFail("A single csv path must yield a single Document, not an array");
    }
    test:assertEquals(result.'type, "text", "csv Document type should be 'text'");
    test:assertEquals(result.metadata?.mimeType, "text/csv", "csv mime type should be text/csv");
    test:assertEquals(result.metadata?.fileName, "Test.csv", "csv fileName should be Test.csv");
    string content = check abstractionTextContent(result);
    test:assertTrue(content.includes("Alice"), "csv content should contain the row data 'Alice'");
}

@test:Config {groups: ["easy"]}
function testDataLoaderAbstractionTextLoaderJsonSingleDocument() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.json");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "json Document type should be 'text'");
    test:assertEquals(document.metadata?.mimeType, "application/json", "json mime type should be application/json");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("ballerina-ai"), "json content should contain the team identifier");
}

@test:Config {groups: ["easy"]}
function testDataLoaderAbstractionTextLoaderMarkdownSingleDocument() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.md");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "md Document type should be 'text'");
    // Markdown carries no mime type from readTextDocument.
    test:assertEquals(document.metadata?.mimeType, (), "md document should not carry a mime type");
    test:assertEquals(document.metadata?.fileName, "Test.md", "md fileName should be Test.md");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("Quick Start Guide"), "md content should include the heading text");
}

@test:Config {groups: ["easy"]}
function testDataLoaderAbstractionPdfLayoutLoaderSmoke() returns error? {
    DataLoader loader = check new PdfLayoutDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "PdfLayout Document type should be 'text'");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.length() > 0, "PdfLayout loader should produce non-empty content");
}

@test:Config {groups: ["easy"]}
function testDataLoaderAbstractionDirectoryLoaderSmoke() returns error? {
    DataLoader loader = check new DirectoryDataLoader(ABSTRACTION_RESOURCE_DIR + "/dir");
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Directory load with multiple supported files should return a Document[]");
    }
    test:assertTrue(result.length() > 0, "Directory loader should load at least one document");
    foreach Document doc in result {
        test:assertEquals(doc.'type, "text", "Each directory document should be of type 'text'");
    }
}

// ===========================================================================
// MEDIUM (5)
// ===========================================================================

@test:Config {groups: ["medium"]}
function testDataLoaderAbstractionTextLoaderMultiFileArray() returns error? {
    DataLoader loader = check new TextDataLoader(
        ABSTRACTION_RESOURCE_DIR + "/Test.csv",
        ABSTRACTION_RESOURCE_DIR + "/Test.tsv",
        ABSTRACTION_RESOURCE_DIR + "/Test.json");
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Multiple paths must yield a Document[]");
    }
    test:assertEquals(result.length(), 3, "Should return three documents for three paths");
    test:assertEquals(result[0].metadata?.mimeType, "text/csv", "First document should be csv");
    test:assertEquals(result[1].metadata?.mimeType, "text/tab-separated-values", "Second document should be tsv");
    test:assertEquals(result[2].metadata?.mimeType, "application/json", "Third document should be json");
}

@test:Config {groups: ["medium"]}
function testDataLoaderAbstractionDirectoryNonRecursiveVsRecursive() returns error? {
    DataLoader nonRecursive = check new DirectoryDataLoader(ABSTRACTION_RESOURCE_DIR + "/dir");
    Document[]|Document|Error nonRecursiveResult = nonRecursive.load();
    if nonRecursiveResult !is Document[] {
        test:assertFail("Non-recursive directory load should return a Document[]");
    }
    // dir/ has mixed.md + mixed.csv supported, notes.txt skipped, nested/ not visited.
    test:assertEquals(nonRecursiveResult.length(), 2, "Non-recursive load should find 2 supported files");

    DataLoader recursive = check new DirectoryDataLoader(ABSTRACTION_RESOURCE_DIR + "/dir", recursive = true);
    Document[]|Document|Error recursiveResult = recursive.load();
    if recursiveResult !is Document[] {
        test:assertFail("Recursive directory load should return a Document[]");
    }
    // Recursive load additionally picks up nested/nested.json.
    test:assertEquals(recursiveResult.length(), 3, "Recursive load should find 3 supported files");
    string[] recursiveNames = from Document doc in recursiveResult
        let string? name = doc.metadata?.fileName
        where name is string
        select name;
    test:assertTrue(recursiveNames.indexOf("nested.json") is int,
            "Recursive load should include nested.json from the subdirectory");
}

@test:Config {groups: ["medium"]}
function testDataLoaderAbstractionPdfLayoutLoaderMetadata() returns error? {
    DataLoader loader = check new PdfLayoutDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "PdfLayout document type should be 'text'");
    Metadata? metadata = document.metadata;
    if metadata is () {
        test:assertFail("PdfLayout document should carry metadata");
    }
    string content = check abstractionTextContent(document);
    test:assertTrue(content.length() > 0, "Layout-aware extraction should produce non-empty text");
}

@test:Config {groups: ["medium"]}
function testDataLoaderAbstractionTextLoaderDocxParsing() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.docx");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "docx document type should be 'text'");
    test:assertEquals(document.metadata?.mimeType,
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "docx mime type should be the OOXML wordprocessing type");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.length() > 0, "docx parsing should yield non-empty text content");
}

@test:Config {groups: ["medium"]}
function testDataLoaderAbstractionTextLoaderPptxParsing() returns error? {
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test presentation.pptx");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "pptx document type should be 'text'");
    test:assertEquals(document.metadata?.mimeType,
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "pptx mime type should be the OOXML presentation type");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.length() > 0, "pptx parsing should yield non-empty text content");
}

// ===========================================================================
// HARD (5)
// ===========================================================================

@test:Config {groups: ["hard"]}
function testDataLoaderAbstractionInitErrorPaths() returns error? {
    // TextDataLoader init must fail for a missing file.
    TextDataLoader|Error missing = new (ABSTRACTION_RESOURCE_DIR + "/no-such-file.pdf");
    if missing !is Error {
        test:assertFail("TextDataLoader init should fail for a missing file");
    }
    test:assertTrue(missing.message().includes("File does not exist"),
            "Init error message should report that the file does not exist");

    // DirectoryDataLoader init must fail when the path points to a file.
    DirectoryDataLoader|Error notDir = new (ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    if notDir !is Error {
        test:assertFail("DirectoryDataLoader init should fail when the path is a file");
    }
    test:assertTrue(notDir.message().includes("not a directory"),
            "Init error should indicate the path is not a directory");
}

@test:Config {groups: ["hard"]}
function testDataLoaderAbstractionUnsupportedTypeLoadError() returns error? {
    // test.txt exists but .txt is not a supported type; init succeeds, load fails.
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/test.txt");
    Document[]|Document|Error result = loader.load();
    if result !is Error {
        test:assertFail("Loading an unsupported .txt file should produce an Error");
    }
    test:assertTrue(result.message().includes("Unsupported file type: txt"),
            "Load error should name the unsupported extension");
}

@test:Config {groups: ["hard"]}
function testDataLoaderAbstractionTextLoaderEmptyResult() returns error? {
    // Zero paths: init succeeds and load returns an empty Document[].
    DataLoader loader = check new TextDataLoader();
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("A loader with no paths should return a Document[] (empty array)");
    }
    test:assertEquals(result.length(), 0, "Empty path list should produce an empty document array");
}

@test:Config {groups: ["hard"]}
function testDataLoaderAbstractionUnicodeRoundTrip() returns error? {
    // Test.md contains non-ASCII characters (smart quote U+2019, em-dash, en-dash).
    DataLoader loader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.md");
    Document document = check abstractionSingleDocument(loader.load());
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("\u{2019}"),
            "Unicode smart-quote should survive the load round-trip");
    test:assertTrue(content.includes("\u{2014}"),
            "Unicode em-dash should survive the load round-trip");
}

@test:Config {groups: ["hard"]}
function testDataLoaderAbstractionConcurrentLoad() returns error? {
    DataLoader csvLoader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    DataLoader jsonLoader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.json");
    DataLoader tsvLoader = check new TextDataLoader(ABSTRACTION_RESOURCE_DIR + "/Test.tsv");

    worker csvWorker returns Document[]|Document|Error {
        return csvLoader.load();
    }
    worker jsonWorker returns Document[]|Document|Error {
        return jsonLoader.load();
    }
    worker tsvWorker returns Document[]|Document|Error {
        return tsvLoader.load();
    }

    Document[]|Document|Error csvResult = wait csvWorker;
    Document[]|Document|Error jsonResult = wait jsonWorker;
    Document[]|Document|Error tsvResult = wait tsvWorker;

    Document csvDoc = check abstractionSingleDocument(csvResult);
    Document jsonDoc = check abstractionSingleDocument(jsonResult);
    Document tsvDoc = check abstractionSingleDocument(tsvResult);

    test:assertEquals(csvDoc.metadata?.mimeType, "text/csv", "Concurrent csv load should be intact");
    test:assertEquals(jsonDoc.metadata?.mimeType, "application/json", "Concurrent json load should be intact");
    test:assertEquals(tsvDoc.metadata?.mimeType, "text/tab-separated-values", "Concurrent tsv load should be intact");
}

// ===========================================================================
// SEVERE (5) -- cloud loaders and URL loader against an in-process mock.
// ===========================================================================

// Mock JSON / text payloads served by the abstraction mock service.
const string GOOGLE_DRIVE_FILE_ID = "drive-file-1";
const string GOOGLE_DRIVE_MISSING_ID = "drive-missing";
const string SHAREPOINT_SITE_ID = "site-1";
const string SHAREPOINT_ITEM_ID = "item-1";
const string SHAREPOINT_MISSING_ID = "item-missing";
const string SALESFORCE_CONTENT_VERSION_ID = "cv-1";

// In-process service mimicking Google Drive v3, MS Graph v1.0 and Salesforce REST.
isolated service /mock on new http:Listener(ABSTRACTION_MOCK_PORT, host = "localhost") {

    // --- URL loader endpoints ---------------------------------------------

    isolated resource function get url/data\.csv() returns http:Response {
        http:Response res = new;
        res.setTextPayload("h1,h2\nx,y\n", contentType = "text/csv");
        return res;
    }

    // No extension in the path; type inferred from Content-Type.
    isolated resource function get url/inferred() returns http:Response {
        http:Response res = new;
        res.setTextPayload("{\"inferred\": true}", contentType = "application/json");
        return res;
    }

    isolated resource function get url/missing() returns http:Response {
        http:Response res = new;
        res.statusCode = 404;
        return res;
    }

    // --- Google Drive v3 endpoints ----------------------------------------

    // File metadata: /drive/v3/files/{id}?fields=...
    isolated resource function get drive/v3/files/[string fileId](http:Request req) returns http:Response {
        http:Response res = new;
        if fileId == GOOGLE_DRIVE_MISSING_ID {
            res.statusCode = 404;
            res.setJsonPayload({'error: {message: "File not found"}});
            return res;
        }
        string? altQuery = req.getQueryParamValue("alt");
        if altQuery == "media" {
            // Plain media download branch.
            res.setTextPayload("name,role\nAda,Engineer\n", contentType = "text/csv");
            return res;
        }
        // Metadata branch.
        res.setJsonPayload({id: fileId, name: "drive-doc.csv", mimeType: "text/csv"});
        return res;
    }

    // --- MS Graph v1.0 endpoints ------------------------------------------

    // Drive item metadata: /v1.0/sites/{site}/drive/items/{item}
    isolated resource function get v1\.0/sites/[string siteId]/drive/items/[string itemId]()
            returns http:Response {
        http:Response res = new;
        if itemId == SHAREPOINT_MISSING_ID {
            res.statusCode = 404;
            res.setJsonPayload({'error: {message: "Item not found"}});
            return res;
        }
        res.setJsonPayload({
            id: itemId,
            name: "sharepoint-doc.md",
            file: {mimeType: "text/markdown"}
        });
        return res;
    }

    // Drive item content: /v1.0/sites/{site}/drive/items/{item}/content
    isolated resource function get v1\.0/sites/[string siteId]/drive/items/[string itemId]/content()
            returns http:Response {
        http:Response res = new;
        res.setTextPayload("# SharePoint Mock\n\nHello from Graph.", contentType = "text/markdown");
        return res;
    }

    // --- Salesforce REST endpoints ----------------------------------------

    // ContentVersion metadata: /services/data/{ver}/sobjects/ContentVersion/{id}
    isolated resource function get services/data/[string apiVersion]/sobjects/ContentVersion/[string id]()
            returns http:Response {
        http:Response res = new;
        res.setJsonPayload({Title: "salesforce-report", FileExtension: "json", FileType: "JSON"});
        return res;
    }

    // ContentVersion binary: /services/data/{ver}/sobjects/ContentVersion/{id}/VersionData
    isolated resource function get services/data/[string apiVersion]/sobjects/ContentVersion/[string id]/VersionData()
            returns http:Response {
        http:Response res = new;
        res.setTextPayload("{\"source\": \"salesforce\"}", contentType = "application/json");
        return res;
    }
}

@test:Config {groups: ["severe"]}
function testDataLoaderAbstractionUrlLoaderAgainstMock() returns error? {
    string base = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock/url`;

    // Happy path: type inferred from URL extension.
    DataLoader csvLoader = new UrlDataLoader([<Url>(base + "/data.csv")]);
    Document csvDoc = check abstractionSingleDocument(csvLoader.load());
    test:assertEquals(csvDoc.metadata?.mimeType, "text/csv", "URL loader should resolve csv by extension");
    string csvContent = check abstractionTextContent(csvDoc);
    test:assertTrue(csvContent.includes("x,y"), "URL loader csv content should match the mock body");

    // Content-type inference: no extension in the URL path.
    DataLoader inferLoader = new UrlDataLoader([<Url>(base + "/inferred")]);
    Document inferDoc = check abstractionSingleDocument(inferLoader.load());
    test:assertEquals(inferDoc.metadata?.mimeType, "application/json",
            "URL loader should infer json from the Content-Type header");

    // Error path: HTTP 404 surfaces as an "HTTP 404" error.
    DataLoader missingLoader = new UrlDataLoader([<Url>(base + "/missing")]);
    Document[]|Document|Error missingResult = missingLoader.load();
    if missingResult !is Error {
        test:assertFail("URL loader should error on a 404 response");
    }
    test:assertTrue(missingResult.message().includes("HTTP 404"),
            "URL loader error should report the HTTP 404 status");
}

@test:Config {groups: ["severe"]}
function testDataLoaderAbstractionUrlLoaderMalformedUrl() returns error? {
    DataLoader loader = new UrlDataLoader([<Url>"not-a-valid-url"]);
    Document[]|Document|Error result = loader.load();
    if result !is Error {
        test:assertFail("URL loader should error on a malformed URL");
    }
    test:assertTrue(result.message().includes("Invalid URL"),
            "Malformed URL should produce an 'Invalid URL' error");
}

@test:Config {groups: ["severe"]}
function testDataLoaderAbstractionGoogleDriveLoaderAgainstMock() returns error? {
    string baseUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;

    // Happy path: a non-Workspace file downloaded via ?alt=media.
    DataLoader loader = check new GoogleDriveDataLoader(
        [{id: GOOGLE_DRIVE_FILE_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "Drive document type should be 'text'");
    test:assertEquals(document.metadata?.mimeType, "text/csv", "Drive csv mime type should be text/csv");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("Ada"), "Drive download content should match the mock body");

    // Error path: a missing file id returns HTTP 404 from metadata fetch.
    DataLoader missingLoader = check new GoogleDriveDataLoader(
        [{id: GOOGLE_DRIVE_MISSING_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error missingResult = missingLoader.load();
    if missingResult !is Error {
        test:assertFail("Drive loader should error for a missing file id");
    }
    test:assertTrue(missingResult.message().includes("HTTP 404"),
            "Drive loader error should report the HTTP 404 status");
}

@test:Config {groups: ["severe"]}
function testDataLoaderAbstractionSharePointLoaderAgainstMock() returns error? {
    string baseUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;

    // Happy path: a file fetched via Microsoft Graph v1.0 shapes.
    DataLoader loader = check new SharePointDataLoader(
        [{siteId: SHAREPOINT_SITE_ID, itemId: SHAREPOINT_ITEM_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "SharePoint document type should be 'text'");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("Hello from Graph"),
            "SharePoint download content should match the mock body");

    // Error path: a missing item id returns HTTP 404 from metadata fetch.
    DataLoader missingLoader = check new SharePointDataLoader(
        [{siteId: SHAREPOINT_SITE_ID, itemId: SHAREPOINT_MISSING_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error missingResult = missingLoader.load();
    if missingResult !is Error {
        test:assertFail("SharePoint loader should error for a missing item id");
    }
    test:assertTrue(missingResult.message().includes("HTTP 404"),
            "SharePoint loader error should report the HTTP 404 status");
}

@test:Config {groups: ["severe"]}
function testDataLoaderAbstractionSalesforceLoaderBatchAgainstMock() returns error? {
    string instanceUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;

    // Happy path: resolve a ContentVersion to its binary VersionData payload.
    DataLoader loader = check new SalesforceDataLoader(
        [SALESFORCE_CONTENT_VERSION_ID],
        accessToken = "mock-token",
        instanceUrl = instanceUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "Salesforce document type should be 'text'");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.includes("salesforce"),
            "Salesforce VersionData content should match the mock body");

    // Volume path: load the same ContentVersion `severeBatchSize` times and
    // confirm every batch entry resolves consistently.
    string[] batchIds = [];
    int i = 0;
    while i < severeBatchSize {
        batchIds.push(SALESFORCE_CONTENT_VERSION_ID);
        i += 1;
    }
    DataLoader batchLoader = check new SalesforceDataLoader(
        batchIds,
        accessToken = "mock-token",
        instanceUrl = instanceUrl);
    Document[]|Document|Error batchResult = batchLoader.load();
    if batchResult !is Document[] {
        test:assertFail("A multi-id Salesforce load should return a Document[]");
    }
    test:assertEquals(batchResult.length(), severeBatchSize,
            "Batch load should return one document per ContentVersion id");
    foreach Document doc in batchResult {
        string docContent = check abstractionTextContent(doc);
        test:assertTrue(docContent.includes("salesforce"),
                "Every batched Salesforce document should carry the mock content");
    }
}
