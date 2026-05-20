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
import ballerina/jballerina.java;
import ballerina/lang.regexp;
import ballerina/log;
import ballerina/mime;

# Represents a data loader that can load documents from various sources.
public type DataLoader isolated object {
    # Loads documents from a source.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error;
};

# Dataloader that can be used to load supported file types as `TextDocument`s.
# Currently supports `pdf`, `docx`, `pptx`, `html`, `htm`, `md`, `csv`, `tsv`, and `json` file types.
public isolated class TextDataLoader {
    *DataLoader;
    final readonly & string[] paths;

    # Initializes the data loader with the given paths.
    # + paths - The paths to the files to load
    # + return - an error if the file does not exist
    public isolated function init(string... paths) returns Error? {
        // Check if the file exists by trying to get metadata
        foreach string path in paths {
            file:MetaData|error metadata = file:getMetaData(path);
            if metadata is error {
                return error Error("File does not exist: " + path);
            }
        }
        self.paths = paths.cloneReadOnly();
    }

    # Loads documents as `TextDocument`s from a source.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = from string path in self.paths
            select check loadDocument(path);
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }
}

isolated function loadDocument(string path) returns Document|Error {
    string? fileType = getFileType(path);
    if fileType is () {
        string extension = getFileExtension(path);
        return error Error(string `Unsupported file type: ${extension}`);
    }

    match fileType {
        HTML|HTM|MARKDOWN => {
            return readTextDocument(path);
        }
        CSV => {
            return readTextDocument(path, MIME_TYPE_CSV);
        }
        TSV => {
            return readTextDocument(path, MIME_TYPE_TSV);
        }
        JSON => {
            return readTextDocument(path, MIME_TYPE_JSON);
        }
        PDF => {
            return readPdfNative(path);
        }
        DOCX => {
            return readDocxNative(path);
        }
        PPTX => {
            return readPptxNative(path);
        }
    }
    return error Error("Unexpected error in file type processing");
}

enum SupportedFileType {
    PDF = "pdf",
    DOCX = "docx",
    PPTX = "pptx",
    HTML = "html",
    HTM = "htm",
    MARKDOWN = "md",
    CSV = "csv",
    TSV = "tsv",
    JSON = "json"
}

const string MIME_TYPE_CSV = "text/csv";
const string MIME_TYPE_TSV = "text/tab-separated-values";
const string MIME_TYPE_JSON = "application/json";

isolated function getFileType(string path) returns SupportedFileType? {
    match getFileExtension(path) {
        "html" => {return HTML;}
        "htm" => {return HTM;}
        "md" => {return MARKDOWN;}
        "pdf" => {return PDF;}
        "docx" => {return DOCX;}
        "pptx" => {return PPTX;}
        "csv" => {return CSV;}
        "tsv" => {return TSV;}
        "json" => {return JSON;}
        _ => {return ();}
    }
}

isolated function getFileExtension(string path) returns string {
    string lowered = path.toLowerAscii();
    int? lastDotIndex = lowered.lastIndexOf(".");
    if lastDotIndex is () {
        return "unknown";
    }
    return lowered.substring(lastDotIndex + 1);
}

isolated function readTextDocument(string filePath, string? mimeType = ()) returns TextDocument|Error {
    do {
        string fileName = check file:basename(filePath);
        file:MetaData meta = check file:getMetaData(filePath);
        string content = check io:fileReadString(filePath);
        Metadata metadata = {fileName, modifiedAt: meta.modifiedTime, fileSize: <decimal>meta.size};
        if mimeType is string {
            metadata.mimeType = mimeType;
        }
        return {content, metadata};
    } on fail error e {
        return error(string `failed to create document from file '${filePath}': ${e.message()}`, e);
    }
}

isolated function readPdfNative(string path) returns TextDocument|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.TextDataLoader",
    name: "readPdf"
} external;

isolated function readDocxNative(string path) returns TextDocument|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.TextDataLoader",
    name: "readDocx"
} external;

isolated function readPptxNative(string path) returns TextDocument|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.TextDataLoader",
    name: "readPptx"
} external;

isolated function readPdfLayoutNative(string path) returns TextDocument|Error = @java:Method {
    'class: "io.ballerina.stdlib.ai.TextDataLoader",
    name: "readPdfLayout"
} external;

# Dataloader that loads PDF files using a layout-aware text extractor.
# Unlike `TextDataLoader` (which uses Apache Tika and linearises text), this
# loader uses Apache PDFBox with position-sorted extraction, preserving the
# reading order of multi-column documents and tables.
public isolated class PdfLayoutDataLoader {
    *DataLoader;
    final readonly & string[] paths;

    # Initializes the data loader with the given PDF paths.
    #
    # + paths - PDF file paths to load
    # + return - an `ai:Error` if any file is missing or has a non-`.pdf` extension
    public isolated function init(string... paths) returns Error? {
        foreach string path in paths {
            file:MetaData|error metadata = file:getMetaData(path);
            if metadata is error {
                return error Error("File does not exist: " + path);
            }
            if getFileExtension(path) != "pdf" {
                return error Error("PdfLayoutDataLoader only supports .pdf files; got: " + path);
            }
        }
        self.paths = paths.cloneReadOnly();
    }

    # Loads each PDF with layout-aware text extraction.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = from string path in self.paths
            select check readPdfLayoutNative(path);
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }
}

# Builds a Document from raw bytes plus a hint for the file type.
# Used by the cloud loaders after they fetch content from the remote service.
#
# + bytes - The raw file bytes
# + mimeType - The reported mime type (may be empty)
# + fileName - The desired fileName in the resulting Document metadata
# + return - A Document, or `ai:Error` if the file type cannot be resolved or parsing fails
public isolated function buildDocumentFromBytes(byte[] bytes, string mimeType, string fileName)
        returns Document|Error {
    SupportedFileType? fileType = getFileTypeFromMime(mimeType);
    if fileType is () {
        fileType = getFileType(fileName);
    }
    if fileType is () {
        return error Error(string `Unsupported content for '${fileName}' `
            + string `(mime: ${mimeType}, extension: ${getFileExtension(fileName)})`);
    }
    return buildDocumentFromBytesWithType(bytes, fileType, fileName);
}

isolated function buildDocumentFromBytesWithType(byte[] bytes, SupportedFileType fileType,
        string fileName) returns Document|Error {
    match fileType {
        HTML|HTM|MARKDOWN|CSV|TSV|JSON => {
            string|error content = string:fromBytes(bytes);
            if content is error {
                return error Error(
                    string `Failed to decode bytes as text for '${fileName}': ${content.message()}`,
                    content);
            }
            string? mt = mimeTypeForTextType(fileType);
            Metadata metadata = {fileName};
            if mt is string {
                metadata.mimeType = mt;
            }
            TextDocument doc = {content, metadata};
            return doc;
        }
        PDF|DOCX|PPTX => {
            string tempPath = check writeTempFile(bytes, fileType);
            TextDocument|Error parsed = loadBinaryFromPath(tempPath, fileType);
            file:Error? removeErr = file:remove(tempPath);
            if removeErr is file:Error {
                log:printWarn(string `Failed to remove temp file '${tempPath}': ${removeErr.message()}`);
            }
            if parsed is Error {
                return parsed;
            }
            string? nativeMime = mimeTypeForBinaryType(fileType);
            Metadata metadata = {fileName};
            if nativeMime is string {
                metadata.mimeType = nativeMime;
            }
            TextDocument doc = {content: parsed.content, metadata};
            return doc;
        }
    }
    return error Error("Unsupported file type after dispatch");
}

# Dataloader that loads every supported file in a directory.
# Files with unsupported extensions are skipped with a log warning.
# Currently supports the same file types as `TextDataLoader`.
public isolated class DirectoryDataLoader {
    *DataLoader;
    final readonly & string[] paths;

    # Initializes the data loader with the given directory.
    #
    # + path - The path to the directory to load
    # + recursive - When `true`, sub-directories are traversed as well. Defaults to `false`
    # + return - an `ai:Error` if the path does not exist or is not a directory
    public isolated function init(string path, boolean recursive = false) returns Error? {
        file:MetaData|error meta = file:getMetaData(path);
        if meta is error {
            return error Error("Directory does not exist: " + path, meta);
        }
        if !meta.dir {
            return error Error("Path is not a directory: " + path);
        }
        string[]|Error collected = collectFiles(path, recursive);
        if collected is Error {
            return collected;
        }
        self.paths = collected.cloneReadOnly();
    }

    # Loads documents from the configured directory.
    # Files with unsupported extensions are skipped with a log warning.
    #
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = [];
        foreach string filePath in self.paths {
            string? fileType = getFileType(filePath);
            if fileType is () {
                log:printWarn(string `Skipping unsupported file: ${filePath}`);
                continue;
            }
            documents.push(check loadDocument(filePath));
        }
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }
}

isolated function collectFiles(string dirPath, boolean recursive) returns string[]|Error {
    string[] files = [];
    file:MetaData[]|error entries = file:readDir(dirPath);
    if entries is error {
        return error Error("Failed to read directory: " + dirPath, entries);
    }
    foreach file:MetaData entry in entries {
        if entry.dir {
            if recursive {
                files.push(...check collectFiles(entry.absPath, true));
            }
            continue;
        }
        files.push(entry.absPath);
    }
    return files;
}

# Dataloader that loads documents from one or more URLs.
# The file type is inferred first from the URL's path extension and, if unknown,
# from the response `Content-Type` header.
# Currently supports the same file types as `TextDataLoader`.
public isolated class UrlDataLoader {
    *DataLoader;
    final readonly & Url[] urls;
    final readonly & map<string|string[]> headers;

    # Initializes the data loader with the given URLs.
    #
    # + urls - The URLs to load documents from
    # + headers - Optional HTTP headers applied to every request (e.g., for bearer-token or API-key auth)
    public isolated function init(Url[] urls, map<string|string[]> headers = {}) {
        self.urls = urls.cloneReadOnly();
        self.headers = headers.cloneReadOnly();
    }

    # Loads documents from the configured URLs.
    #
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = [];
        foreach Url url in self.urls {
            documents.push(check self.loadUrl(url));
        }
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }

    private isolated function loadUrl(Url url) returns Document|Error {
        [string, string] [origin, path] = check splitUrl(url);
        http:Client httpClient;
        do {
            httpClient = check new (origin);
        } on fail error e {
            return error Error(string `Failed to create HTTP client for '${url}': ${e.message()}`, e);
        }

        http:Response response;
        do {
            response = check httpClient->get(path, self.headers);
        } on fail error e {
            return error Error(string `Failed to fetch URL '${url}': ${e.message()}`, e);
        }

        if response.statusCode < 200 || response.statusCode >= 300 {
            return error Error(string `Failed to fetch URL '${url}': HTTP ${response.statusCode}`);
        }

        string contentType = response.getContentType();
        SupportedFileType? fileType = getFileTypeFromUrl(url);
        if fileType is () {
            fileType = getFileTypeFromMime(contentType);
        }
        if fileType is () {
            return error Error(string `Unsupported content for URL '${url}' `
                + string `(extension: ${getFileExtensionFromUrl(url)}, content-type: ${contentType})`);
        }
        return buildDocumentFromResponse(url, fileType, response);
    }
}

isolated function buildDocumentFromResponse(Url url, SupportedFileType fileType,
        http:Response response) returns Document|Error {
    string fileName = getFileNameFromUrl(url, fileType);
    match fileType {
        HTML|HTM|MARKDOWN|CSV|TSV|JSON => {
            string|http:ClientError textPayload = response.getTextPayload();
            if textPayload is http:ClientError {
                return error Error(string `Failed to read text payload from '${url}': ${textPayload.message()}`,
                    textPayload);
            }
            string? mimeType = mimeTypeForTextType(fileType);
            Metadata metadata = {fileName};
            if mimeType is string {
                metadata.mimeType = mimeType;
            }
            TextDocument doc = {content: textPayload, metadata};
            return doc;
        }
        PDF|DOCX|PPTX => {
            byte[]|http:ClientError binaryPayload = response.getBinaryPayload();
            if binaryPayload is http:ClientError {
                return error Error(string `Failed to read binary payload from '${url}': ${binaryPayload.message()}`,
                    binaryPayload);
            }
            string tempPath = check writeTempFile(binaryPayload, fileType);
            TextDocument|Error parsed = loadBinaryFromPath(tempPath, fileType);
            file:Error? removeErr = file:remove(tempPath);
            if removeErr is file:Error {
                log:printWarn(string `Failed to remove temp file '${tempPath}': ${removeErr.message()}`);
            }
            if parsed is Error {
                return parsed;
            }
            // The native parser stores metadata as an untyped map; reading it as the
            // typed Metadata record fails the runtime cast. Build a fresh Metadata
            // record with the URL-derived fileName and the known per-type mime.
            string? nativeMime = mimeTypeForBinaryType(fileType);
            Metadata metadata = {fileName};
            if nativeMime is string {
                metadata.mimeType = nativeMime;
            }
            TextDocument doc = {content: parsed.content, metadata};
            return doc;
        }
    }
    return error Error("Unexpected error in URL content processing");
}

isolated function loadBinaryFromPath(string path, SupportedFileType fileType) returns TextDocument|Error {
    match fileType {
        PDF => {
            return readPdfNative(path);
        }
        DOCX => {
            return readDocxNative(path);
        }
        PPTX => {
            return readPptxNative(path);
        }
    }
    return error Error("Unsupported binary file type");
}

isolated function writeTempFile(byte[] bytes, SupportedFileType fileType) returns string|Error {
    string|file:Error tempPath = file:createTemp("." + fileType, "ai-url-loader-");
    if tempPath is file:Error {
        return error Error("Failed to create temp file: " + tempPath.message(), tempPath);
    }
    io:Error? writeResult = io:fileWriteBytes(tempPath, bytes);
    if writeResult is io:Error {
        file:Error? removeErr = file:remove(tempPath);
        if removeErr is file:Error {
            log:printWarn(string `Failed to remove temp file '${tempPath}': ${removeErr.message()}`);
        }
        return error Error("Failed to write temp file: " + writeResult.message(), writeResult);
    }
    return tempPath;
}

isolated function splitUrl(string url) returns [string, string]|Error {
    int? schemeEnd = url.indexOf("://");
    if schemeEnd is () {
        return error Error("Invalid URL: " + url);
    }
    int afterScheme = schemeEnd + 3;
    int? pathStart = url.indexOf("/", afterScheme);
    if pathStart is () {
        return [url, "/"];
    }
    return [url.substring(0, pathStart), url.substring(pathStart)];
}

isolated function getFileExtensionFromUrl(string url) returns string {
    string trimmed = url;
    int? queryIdx = trimmed.indexOf("?");
    if queryIdx is int {
        trimmed = trimmed.substring(0, queryIdx);
    }
    int? fragmentIdx = trimmed.indexOf("#");
    if fragmentIdx is int {
        trimmed = trimmed.substring(0, fragmentIdx);
    }
    return getFileExtension(trimmed);
}

isolated function getFileTypeFromUrl(string url) returns SupportedFileType? {
    match getFileExtensionFromUrl(url) {
        "html" => {return HTML;}
        "htm" => {return HTM;}
        "md" => {return MARKDOWN;}
        "pdf" => {return PDF;}
        "docx" => {return DOCX;}
        "pptx" => {return PPTX;}
        "csv" => {return CSV;}
        "tsv" => {return TSV;}
        "json" => {return JSON;}
        _ => {return ();}
    }
}

isolated function getFileTypeFromMime(string contentType) returns SupportedFileType? {
    string baseType = regexp:split(re `;`, contentType)[0].trim().toLowerAscii();
    match baseType {
        "application/pdf" => {return PDF;}
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => {return DOCX;}
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" => {return PPTX;}
        "text/html"|"application/xhtml+xml" => {return HTML;}
        "text/markdown" => {return MARKDOWN;}
        MIME_TYPE_CSV => {return CSV;}
        MIME_TYPE_TSV => {return TSV;}
        MIME_TYPE_JSON => {return JSON;}
        _ => {return ();}
    }
}

isolated function mimeTypeForTextType(SupportedFileType fileType) returns string? {
    match fileType {
        CSV => {return MIME_TYPE_CSV;}
        TSV => {return MIME_TYPE_TSV;}
        JSON => {return MIME_TYPE_JSON;}
        HTML|HTM => {return mime:TEXT_HTML;}
        MARKDOWN => {return "text/markdown";}
    }
    return ();
}

isolated function mimeTypeForBinaryType(SupportedFileType fileType) returns string? {
    match fileType {
        PDF => {return "application/pdf";}
        DOCX => {return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";}
        PPTX => {return "application/vnd.openxmlformats-officedocument.presentationml.presentation";}
    }
    return ();
}

isolated function getFileNameFromUrl(string url, SupportedFileType fileType) returns string {
    string trimmed = url;
    int? queryIdx = trimmed.indexOf("?");
    if queryIdx is int {
        trimmed = trimmed.substring(0, queryIdx);
    }
    int? fragmentIdx = trimmed.indexOf("#");
    if fragmentIdx is int {
        trimmed = trimmed.substring(0, fragmentIdx);
    }
    int? lastSlash = trimmed.lastIndexOf("/");
    string lastSegment = lastSlash is int ? trimmed.substring(lastSlash + 1) : trimmed;
    if lastSegment == "" {
        return string `index.${fileType}`;
    }
    return lastSegment;
}
