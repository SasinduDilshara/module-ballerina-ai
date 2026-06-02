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
//   - consts `ABSTRACTION_MOCK_PORT`, `ABSTRACTION_RESOURCE_DIR`,
//     `GOOGLE_DRIVE_FILE_ID`
//   - helpers `abstractionSingleDocument`, `abstractionTextContent`
//   - `configurable int severeBatchSize`
//
// All new function names are prefixed `testParamDataLoader`; all new
// module-level consts are prefixed `PARAMCOV_`.

import ballerina/http;
import ballerina/test;

// ---------------------------------------------------------------------------
// Local-only, PARAMCOV_-prefixed module-level declarations.
// ---------------------------------------------------------------------------

// A dedicated mock listener for folder-listing endpoints that the in-scope
// `/mock` service does not expose (Drive folder query, SharePoint /children).
const int PARAMCOV_FOLDER_MOCK_PORT = 18911;

// Drive resource ids served by the folder mock.
const string PARAMCOV_DRIVE_FOLDER_ID = "drive-folder-1";
const string PARAMCOV_DRIVE_SUBFOLDER_ID = "drive-subfolder-1";
const string PARAMCOV_DRIVE_CHILD_ID = "drive-child-1";
const string PARAMCOV_DRIVE_NESTED_ID = "drive-nested-1";

// SharePoint resource ids served by the folder mock.
const string PARAMCOV_SP_SITE_ID = "pc-site-1";
const string PARAMCOV_SP_FOLDER_ID = "pc-folder-1";
const string PARAMCOV_SP_SUBFOLDER_ID = "pc-subfolder-1";
const string PARAMCOV_SP_FILE_ID = "pc-file-1";
const string PARAMCOV_SP_NESTED_FILE_ID = "pc-nested-file-1";

// In-process mock exposing the folder-listing shapes for Drive and SharePoint
// (kind == "folder", recursive true/false). A separate listener/port is used
// because the in-scope `/mock` service has no folder-enumeration resources.
isolated service /paramcov on new http:Listener(PARAMCOV_FOLDER_MOCK_PORT, host = "localhost") {

    // --- Google Drive folder-listing + file endpoints ---------------------

    // File-by-id: metadata branch and ?alt=media download branch.
    isolated resource function get drive/v3/files/[string fileId](http:Request req)
            returns http:Response {
        http:Response res = new;
        string? altQuery = req.getQueryParamValue("alt");
        if altQuery == "media" {
            res.setTextPayload("id,label\n1,from-drive-folder\n", contentType = "text/csv");
            return res;
        }
        res.setJsonPayload({id: fileId, name: fileId + ".csv", mimeType: "text/csv"});
        return res;
    }

    // Folder query: /drive/v3/files?q=...&fields=files(id,name,mimeType)
    isolated resource function get drive/v3/files(http:Request req) returns http:Response {
        http:Response res = new;
        string? q = req.getQueryParamValue("q");
        string query = q ?: "";
        json files;
        if query.includes(PARAMCOV_DRIVE_FOLDER_ID) {
            // Top folder: one csv file + one sub-folder.
            files = [
                {id: PARAMCOV_DRIVE_CHILD_ID, name: "child.csv", mimeType: "text/csv"},
                {
                    id: PARAMCOV_DRIVE_SUBFOLDER_ID,
                    name: "sub",
                    mimeType: "application/vnd.google-apps.folder"
                }
            ];
        } else if query.includes(PARAMCOV_DRIVE_SUBFOLDER_ID) {
            // Sub-folder: a single nested csv file.
            files = [{id: PARAMCOV_DRIVE_NESTED_ID, name: "nested.csv", mimeType: "text/csv"}];
        } else {
            files = [];
        }
        res.setJsonPayload({files: files});
        return res;
    }

    // --- SharePoint folder-listing + file endpoints -----------------------

    // Drive item children: /v1.0/sites/{site}/drive/items/{item}/children
    isolated resource function get v1\.0/sites/[string siteId]/drive/items/[string itemId]/children()
            returns http:Response {
        http:Response res = new;
        json value;
        if itemId == PARAMCOV_SP_FOLDER_ID {
            value = [
                {id: PARAMCOV_SP_FILE_ID, name: "doc.md", file: {mimeType: "text/markdown"}},
                {id: PARAMCOV_SP_SUBFOLDER_ID, name: "sub", folder: {childCount: 1}}
            ];
        } else if itemId == PARAMCOV_SP_SUBFOLDER_ID {
            value = [
                {
                    id: PARAMCOV_SP_NESTED_FILE_ID,
                    name: "nested.md",
                    file: {mimeType: "text/markdown"}
                }
            ];
        } else {
            value = [];
        }
        res.setJsonPayload({value: value});
        return res;
    }

    // Drive item metadata: /v1.0/sites/{site}/drive/items/{item}
    isolated resource function get v1\.0/sites/[string siteId]/drive/items/[string itemId]()
            returns http:Response {
        http:Response res = new;
        res.setJsonPayload({
            id: itemId,
            name: itemId + ".md",
            file: {mimeType: "text/markdown"}
        });
        return res;
    }

    // Drive item content: /v1.0/sites/{site}/drive/items/{item}/content
    isolated resource function get v1\.0/sites/[string siteId]/drive/items/[string itemId]/content()
            returns http:Response {
        http:Response res = new;
        res.setTextPayload("# Folder Mock\n\nContent for " + itemId, contentType = "text/markdown");
        return res;
    }
}

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
// PdfLayoutDataLoader -- variadic `paths` count + extension/missing variants.
// Local fixtures, runs OFFLINE => group "easy".
// ===========================================================================

// `paths` variadic: ZERO arguments.
@test:Config {groups: ["easy"]}
function testParamDataLoaderPdfLayoutZeroPaths() returns error? {
    DataLoader loader = check new PdfLayoutDataLoader();
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("PdfLayoutDataLoader with zero paths must return a Document[]");
    }
    test:assertEquals(result.length(), 0, "Zero paths must yield an empty document array");
}

// `paths` variadic: exactly ONE argument.
@test:Config {groups: ["easy"]}
function testParamDataLoaderPdfLayoutOnePath() returns error? {
    DataLoader loader = check new PdfLayoutDataLoader(ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text", "PdfLayout single load should produce a text Document");
    string content = check abstractionTextContent(document);
    test:assertTrue(content.length() > 0, "PdfLayout content should be non-empty");
}

// `paths` variadic: SEVERAL arguments.
@test:Config {groups: ["easy"]}
function testParamDataLoaderPdfLayoutSeveralPaths() returns error? {
    DataLoader loader = check new PdfLayoutDataLoader(
        ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf",
        ABSTRACTION_RESOURCE_DIR + "/TestDoc.pdf");
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Several PDF paths must yield a Document[]");
    }
    test:assertEquals(result.length(), 2, "Two PDF paths must yield two documents");
}

// Extension variant: a NON-.pdf extension -- init rejects it.
@test:Config {groups: ["easy"]}
function testParamDataLoaderPdfLayoutNonPdfExtension() returns error? {
    PdfLayoutDataLoader|Error loader = new (ABSTRACTION_RESOURCE_DIR + "/Test.csv");
    if loader !is Error {
        test:assertFail("PdfLayoutDataLoader init should reject a non-.pdf extension");
    }
    test:assertTrue(loader.message().includes("only supports .pdf"),
            "Init error should state that only .pdf files are supported");
}

// Path variant: a MISSING file -- init itself fails.
@test:Config {groups: ["easy"]}
function testParamDataLoaderPdfLayoutMissingFile() returns error? {
    PdfLayoutDataLoader|Error loader = new (ABSTRACTION_RESOURCE_DIR + "/no-such.pdf");
    if loader !is Error {
        test:assertFail("PdfLayoutDataLoader init should fail for a missing file");
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
// GoogleDriveDataLoader -- `kind` file/folder, `recursive` true/false,
// `baseUrl` default/override, `*CloudHttpConfig` default/customized.
// Runs against the in-scope/folder mocks => group "medium".
// ===========================================================================

// `GoogleDriveResource.kind` value: "file" + `baseUrl` OVERRIDE (the mock).
@test:Config {groups: ["medium"]}
function testParamDataLoaderGoogleDriveKindFile() returns error? {
    string baseUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;
    DataLoader loader = check new GoogleDriveDataLoader(
        [{id: GOOGLE_DRIVE_FILE_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.metadata?.mimeType, "text/csv",
            "Drive kind=file should download and resolve the csv document");
}

// `GoogleDriveResource.kind` value: "folder" with `recursive` FALSE.
@test:Config {groups: ["medium"]}
function testParamDataLoaderGoogleDriveKindFolderNonRecursive() returns error? {
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new GoogleDriveDataLoader(
        [{id: PARAMCOV_DRIVE_FOLDER_ID, kind: "folder", recursive: false}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error result = loader.load();
    if result !is Document {
        test:assertFail("Non-recursive folder with one file should yield a single Document");
    }
    test:assertEquals(result.'type, "text",
            "Drive folder non-recursive load should produce a text Document");
}

// `GoogleDriveResource.recursive` value: TRUE -- descends into the sub-folder.
@test:Config {groups: ["medium"]}
function testParamDataLoaderGoogleDriveFolderRecursiveTrue() returns error? {
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new GoogleDriveDataLoader(
        [{id: PARAMCOV_DRIVE_FOLDER_ID, kind: "folder", recursive: true}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Recursive folder load should return a Document[]");
    }
    // Top folder has 1 file; the sub-folder adds 1 nested file => 2 total.
    test:assertEquals(result.length(), 2,
            "recursive=true should load files from the sub-folder too");
}

// `GoogleDriveConfig.baseUrl` value: the DEFAULT (no override). The init must
// still succeed -- the HTTP client is created against the real Google base URL.
@test:Config {groups: ["medium"]}
function testParamDataLoaderGoogleDriveDefaultBaseUrl() returns error? {
    GoogleDriveDataLoader|Error loader = new (
        [{id: GOOGLE_DRIVE_FILE_ID, kind: "file"}],
        accessToken = "mock-token");
    if loader is Error {
        test:assertFail("GoogleDriveDataLoader init should succeed with the default baseUrl");
    }
}

// `*CloudHttpConfig` axis: ONE customized field (`timeout`) vs the default.
@test:Config {groups: ["medium"]}
function testParamDataLoaderGoogleDriveCustomHttpConfig() returns error? {
    string baseUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;
    DataLoader loader = check new GoogleDriveDataLoader(
        [{id: GOOGLE_DRIVE_FILE_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl,
        timeout = 30);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text",
            "A customized CloudHttpConfig.timeout should not break the load");
}

// ===========================================================================
// SharePointDataLoader -- `kind` file/folder, `recursive` true/false,
// `apiVersion` default/custom. Runs against the in-scope/folder mocks => "medium".
// ===========================================================================

// `SharePointResource.kind` value: "file" + `apiVersion` DEFAULT (v1.0).
@test:Config {groups: ["medium"]}
function testParamDataLoaderSharePointKindFileDefaultApiVersion() returns error? {
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new SharePointDataLoader(
        [{siteId: PARAMCOV_SP_SITE_ID, itemId: PARAMCOV_SP_FILE_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text",
            "SharePoint kind=file with default apiVersion should produce a text Document");
}

// `SharePointResource.kind` value: "folder" with `recursive` FALSE.
@test:Config {groups: ["medium"]}
function testParamDataLoaderSharePointKindFolderNonRecursive() returns error? {
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new SharePointDataLoader(
        [{
            siteId: PARAMCOV_SP_SITE_ID,
            itemId: PARAMCOV_SP_FOLDER_ID,
            kind: "folder",
            recursive: false
        }],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error result = loader.load();
    if result !is Document {
        test:assertFail("Non-recursive folder with one file should yield a single Document");
    }
    test:assertEquals(result.'type, "text",
            "SharePoint folder non-recursive load should produce a text Document");
}

// `SharePointResource.recursive` value: TRUE -- descends into the sub-folder.
@test:Config {groups: ["medium"]}
function testParamDataLoaderSharePointFolderRecursiveTrue() returns error? {
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new SharePointDataLoader(
        [{
            siteId: PARAMCOV_SP_SITE_ID,
            itemId: PARAMCOV_SP_FOLDER_ID,
            kind: "folder",
            recursive: true
        }],
        accessToken = "mock-token",
        baseUrl = baseUrl);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Recursive folder load should return a Document[]");
    }
    // Top folder has 1 file; the sub-folder adds 1 nested file => 2 total.
    test:assertEquals(result.length(), 2,
            "recursive=true should load files from the sub-folder too");
}

// `SharePointConfig.apiVersion` value: a CUSTOM version segment.
@test:Config {groups: ["medium"]}
function testParamDataLoaderSharePointCustomApiVersion() returns error? {
    // The folder mock's resource paths are version-agnostic in the path param,
    // so a custom apiVersion still routes correctly while exercising the field.
    string baseUrl = string `http://localhost:${PARAMCOV_FOLDER_MOCK_PORT}/paramcov`;
    DataLoader loader = check new SharePointDataLoader(
        [{siteId: PARAMCOV_SP_SITE_ID, itemId: PARAMCOV_SP_FILE_ID, kind: "file"}],
        accessToken = "mock-token",
        baseUrl = baseUrl,
        apiVersion = "beta");
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text",
            "A custom apiVersion ('beta') should still resolve the document");
}

// ===========================================================================
// SalesforceDataLoader -- `contentVersionIds` count, `apiVersion` default/custom.
// Runs against the in-scope mock => group "medium".
// ===========================================================================

// `contentVersionIds` list size: exactly ONE id + `apiVersion` DEFAULT (v60.0).
@test:Config {groups: ["medium"]}
function testParamDataLoaderSalesforceSingleIdDefaultApiVersion() returns error? {
    string instanceUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;
    DataLoader loader = check new SalesforceDataLoader(
        ["cv-paramcov-1"],
        accessToken = "mock-token",
        instanceUrl = instanceUrl);
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text",
            "A single ContentVersion id with the default apiVersion should resolve");
}

// `contentVersionIds` list size: SEVERAL ids.
@test:Config {groups: ["medium"]}
function testParamDataLoaderSalesforceSeveralIds() returns error? {
    string instanceUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;
    DataLoader loader = check new SalesforceDataLoader(
        ["cv-paramcov-1", "cv-paramcov-2", "cv-paramcov-3"],
        accessToken = "mock-token",
        instanceUrl = instanceUrl);
    Document[]|Document|Error result = loader.load();
    if result !is Document[] {
        test:assertFail("Several ContentVersion ids must yield a Document[]");
    }
    test:assertEquals(result.length(), 3, "Three ids must yield three documents");
}

// `SalesforceConfig.apiVersion` value: a CUSTOM version segment.
@test:Config {groups: ["medium"]}
function testParamDataLoaderSalesforceCustomApiVersion() returns error? {
    string instanceUrl = string `http://localhost:${ABSTRACTION_MOCK_PORT}/mock`;
    DataLoader loader = check new SalesforceDataLoader(
        ["cv-paramcov-1"],
        accessToken = "mock-token",
        instanceUrl = instanceUrl,
        apiVersion = "v59.0");
    // The mock's Salesforce resources accept any apiVersion path param.
    Document document = check abstractionSingleDocument(loader.load());
    test:assertEquals(document.'type, "text",
            "A custom apiVersion ('v59.0') should still resolve the document");
}

// ===========================================================================
// buildDocumentFromBytes -- public function, mime/extension resolution variants.
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
