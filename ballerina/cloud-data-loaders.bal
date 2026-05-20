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

import ballerina/http;
import ballerina/url;

// =============================================================================
// Shared cloud HTTP configuration -- cloneable subset of `http:ClientConfiguration`.
// `auth` is supplied separately as an access token (BearerTokenConfig is used
// internally), because `http:ClientAuthConfig` cannot be cloned to readonly.
// =============================================================================

# Cloneable subset of `http:ClientConfiguration` accepted by the cloud data
# loaders. Mirrors the fields the `ai.intelligence` client exposes.
public type CloudHttpConfig record {|
    # HTTP version understood by the client. Defaults to HTTP/2
    http:HttpVersion httpVersion = http:HTTP_2_0;
    # Configurations related to HTTP/1.x protocol
    http:ClientHttp1Settings http1Settings = {};
    # Configurations related to HTTP/2 protocol
    http:ClientHttp2Settings http2Settings = {};
    # Maximum time (seconds) to wait for a response before closing the connection
    decimal timeout = 60;
    # Whether to set the `forwarded`/`x-forwarded` header
    string forwarded = "disable";
    # Redirect-following configuration
    http:FollowRedirects followRedirects?;
    # Connection-pool configuration
    http:PoolConfiguration poolConfig?;
    # HTTP caching configuration
    http:CacheConfig cache = {};
    # `accept-encoding` handling strategy
    http:Compression compression = http:COMPRESSION_AUTO;
    # Circuit-breaker configuration
    http:CircuitBreakerConfig circuitBreaker?;
    # Retry configuration
    http:RetryConfig retryConfig?;
    # Cookie configuration
    http:CookieConfig cookieConfig?;
    # Inbound response size limits
    http:ResponseLimitConfigs responseLimits = {};
    # TLS configuration
    http:ClientSecureSocket secureSocket?;
    # Proxy configuration
    http:ProxyConfig proxy?;
    # Client socket configuration
    http:ClientSocketConfig socketConfig = {};
    # Whether constraint-based payload validation is enabled
    boolean validation = true;
    # Whether relaxed data binding is enabled on the client side
    boolean laxDataBinding = true;
|};

// Accepts any record that includes `CloudHttpConfig` (each concrete config type adds
// service-specific fields). The closed `CloudHttpConfig` would reject those records,
// so the open shape with rest type `anydata...` is used here.
isolated function toClientConfig(record {| *CloudHttpConfig; anydata...; |} cfg, string accessToken)
        returns http:ClientConfiguration {
    http:BearerTokenConfig auth = {token: accessToken};
    return {
        auth,
        httpVersion: cfg.httpVersion,
        http1Settings: cfg.http1Settings,
        http2Settings: cfg.http2Settings,
        timeout: cfg.timeout,
        forwarded: cfg.forwarded,
        followRedirects: cfg?.followRedirects,
        poolConfig: cfg?.poolConfig,
        cache: cfg.cache,
        compression: cfg.compression,
        circuitBreaker: cfg?.circuitBreaker,
        retryConfig: cfg?.retryConfig,
        cookieConfig: cfg?.cookieConfig,
        responseLimits: cfg.responseLimits,
        secureSocket: cfg?.secureSocket,
        proxy: cfg?.proxy,
        socketConfig: cfg.socketConfig,
        validation: cfg.validation,
        laxDataBinding: cfg.laxDataBinding
    };
}

// =============================================================================
// GoogleDriveDataLoader
// =============================================================================

const string GOOGLE_DRIVE_DEFAULT_BASE = "https://www.googleapis.com";
const string GOOGLE_WORKSPACE_PREFIX = "application/vnd.google-apps.";
const string GOOGLE_DOC_MIME = "application/vnd.google-apps.document";
const string GOOGLE_SHEET_MIME = "application/vnd.google-apps.spreadsheet";
const string GOOGLE_SLIDES_MIME = "application/vnd.google-apps.presentation";
const string GOOGLE_FOLDER_MIME = "application/vnd.google-apps.folder";

# Configuration for `GoogleDriveDataLoader`.
public type GoogleDriveConfig record {|
    *CloudHttpConfig;
    # OAuth2 bearer token used as the `Authorization` header
    string accessToken;
    # Base URL of the Google API. Override for testing
    string baseUrl = GOOGLE_DRIVE_DEFAULT_BASE;
|};

# Describes a single Google Drive resource to load.
public type GoogleDriveResource record {|
    # File or folder ID
    string id;
    # `"file"` to load this resource directly, `"folder"` to enumerate its children
    "file"|"folder" kind = "file";
    # When `kind` is `"folder"`, whether to descend into sub-folders
    boolean recursive = false;
|};

# Loads documents from Google Drive. Files are downloaded via `?alt=media`;
# Google Workspace files (Docs / Sheets / Slides) are exported to a supported
# format (Markdown / CSV / PDF) before parsing.
public isolated class GoogleDriveDataLoader {
    *DataLoader;
    final readonly & GoogleDriveResource[] resources;
    final http:Client httpClient;

    # Initialises the data loader.
    #
    # + resources - Google Drive resources to load (file or folder)
    # + config - HTTP and auth configuration
    # + return - an `ai:Error` if the HTTP client cannot be created
    public isolated function init(GoogleDriveResource[] resources, *GoogleDriveConfig config)
            returns Error? {
        self.resources = resources.cloneReadOnly();
        http:ClientConfiguration clientConfig = toClientConfig(config, config.accessToken);
        http:Client|http:Error httpClient = new (config.baseUrl, clientConfig);
        if httpClient is http:Error {
            return error Error("Failed to create Google Drive HTTP client: " + httpClient.message(),
                httpClient);
        }
        self.httpClient = httpClient;
    }

    # Loads documents from the configured resources.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = [];
        foreach GoogleDriveResource res in self.resources {
            check self.loadResource(res, documents);
        }
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }

    private isolated function loadResource(GoogleDriveResource res, Document[] documents)
            returns Error? {
        if res.kind == "folder" {
            string[] childIds = check self.listFolder(res.id, res.recursive);
            foreach string childId in childIds {
                check self.loadResource({id: childId, kind: "file"}, documents);
            }
            return;
        }
        Document doc = check self.loadFile(res.id);
        documents.push(doc);
    }

    private isolated function loadFile(string fileId) returns Document|Error {
        DriveFileMetadata meta = check self.fetchMetadata(fileId);
        string mimeType = meta.mimeType;

        if mimeType.startsWith(GOOGLE_WORKSPACE_PREFIX) {
            return self.exportWorkspaceFile(fileId, meta);
        }

        // Plain download for non-Workspace files.
        string path = string `/drive/v3/files/${fileId}?alt=media`;
        http:Response|http:ClientError raw = self.httpClient->get(path);
        if raw is http:ClientError {
            return error Error(string `Drive download failed for ${fileId}: ${raw.message()}`, raw);
        }
        return self.buildFromResponse(raw, mimeType, meta.name, fileId);
    }

    private isolated function fetchMetadata(string fileId) returns DriveFileMetadata|Error {
        string path = string `/drive/v3/files/${fileId}?fields=id,name,mimeType`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `Drive metadata fetch failed for ${fileId}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode != 200 {
            return error Error(string `Drive metadata fetch returned HTTP ${resp.statusCode} for ${fileId}`);
        }
        json|http:ClientError payload = resp.getJsonPayload();
        if payload is http:ClientError {
            return error Error("Drive metadata payload is not JSON: " + payload.message(), payload);
        }
        DriveFileMetadata|error meta = payload.cloneWithType(DriveFileMetadata);
        if meta is error {
            return error Error("Drive metadata shape mismatch: " + meta.message(), meta);
        }
        return meta;
    }

    private isolated function exportWorkspaceFile(string fileId, DriveFileMetadata meta)
            returns Document|Error {
        [string, string]|Error exportInfo = self.exportTarget(meta.mimeType);
        if exportInfo is Error {
            return exportInfo;
        }
        [string, string] [exportMime, _] = exportInfo;
        string encoded = check encodeQuery(exportMime);
        string path = string `/drive/v3/files/${fileId}/export?mimeType=${encoded}`;
        http:Response|http:ClientError raw = self.httpClient->get(path);
        if raw is http:ClientError {
            return error Error(string `Drive export failed for ${fileId}: ${raw.message()}`, raw);
        }
        // Workspace files don't carry a meaningful extension; build a synthetic file name.
        string fileName = meta.name + suffixForMime(exportMime);
        return self.buildFromResponse(raw, exportMime, fileName, fileId);
    }

    private isolated function exportTarget(string workspaceMime) returns [string, string]|Error {
        match workspaceMime {
            GOOGLE_DOC_MIME => {
                return ["text/markdown", "markdown"];
            }
            GOOGLE_SHEET_MIME => {
                return ["text/csv", "csv"];
            }
            GOOGLE_SLIDES_MIME => {
                return ["application/pdf", "pdf"];
            }
        }
        return error Error(string `Google Workspace mime '${workspaceMime}' has no supported export target`);
    }

    private isolated function listFolder(string folderId, boolean recursive)
            returns string[]|Error {
        string[] fileIds = [];
        DriveFileMetadata[] children = check self.fetchFolderChildren(folderId);
        foreach DriveFileMetadata child in children {
            if child.mimeType == GOOGLE_FOLDER_MIME {
                if recursive {
                    fileIds.push(...check self.listFolder(child.id, true));
                }
                continue;
            }
            fileIds.push(child.id);
        }
        return fileIds;
    }

    private isolated function fetchFolderChildren(string folderId)
            returns DriveFileMetadata[]|Error {
        string q = check encodeQuery(string `'${folderId}' in parents and trashed = false`);
        string path = string `/drive/v3/files?q=${q}&fields=files(id,name,mimeType)`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error("Drive folder listing failed: " + resp.message(), resp);
        }
        if resp.statusCode != 200 {
            return error Error(string `Drive folder listing returned HTTP ${resp.statusCode}`);
        }
        json|http:ClientError payload = resp.getJsonPayload();
        if payload is http:ClientError {
            return error Error("Drive folder payload is not JSON: " + payload.message(), payload);
        }
        DriveFolderListing|error listing = payload.cloneWithType(DriveFolderListing);
        if listing is error {
            return error Error("Drive folder listing shape mismatch: " + listing.message(), listing);
        }
        return listing.files;
    }

    private isolated function buildFromResponse(http:Response response, string mimeType,
            string fileName, string fileId) returns Document|Error {
        if response.statusCode < 200 || response.statusCode >= 300 {
            return error Error(string `Drive content fetch returned HTTP ${response.statusCode} for ${fileId}`);
        }
        byte[]|http:ClientError bytes = response.getBinaryPayload();
        if bytes is http:ClientError {
            return error Error("Failed to read Drive payload: " + bytes.message(), bytes);
        }
        return buildDocumentFromBytes(bytes, mimeType, fileName);
    }
}

type DriveFileMetadata record {|
    string id;
    string name;
    string mimeType;
|};

type DriveFolderListing record {|
    DriveFileMetadata[] files;
|};

isolated function suffixForMime(string mime) returns string {
    match mime {
        "text/markdown" => {return ".md";}
        "text/csv" => {return ".csv";}
        "application/pdf" => {return ".pdf";}
        "text/html" => {return ".html";}
        "application/json" => {return ".json";}
    }
    return "";
}

isolated function encodeQuery(string raw) returns string|Error {
    string|url:Error encoded = url:encode(raw, "UTF-8");
    if encoded is url:Error {
        return error Error("Failed to URL-encode query: " + encoded.message(), encoded);
    }
    return encoded;
}

// =============================================================================
// SharePointDataLoader
// =============================================================================

const string SHAREPOINT_DEFAULT_BASE = "https://graph.microsoft.com";

# Configuration for `SharePointDataLoader`.
public type SharePointConfig record {|
    *CloudHttpConfig;
    # OAuth2 bearer token (Microsoft Graph)
    string accessToken;
    # Base URL of Microsoft Graph. Override for testing
    string baseUrl = SHAREPOINT_DEFAULT_BASE;
    # Graph API version segment (e.g., `v1.0`, `beta`)
    string apiVersion = "v1.0";
|};

# Describes a single SharePoint resource to load.
public type SharePointResource record {|
    # SharePoint site ID
    string siteId;
    # Drive item ID (file or folder)
    string itemId;
    # `"file"` to load directly, `"folder"` to enumerate its children
    "file"|"folder" kind = "file";
    # When `kind` is `"folder"`, whether to descend into sub-folders
    boolean recursive = false;
|};

# Loads documents from SharePoint via the Microsoft Graph API.
public isolated class SharePointDataLoader {
    *DataLoader;
    final readonly & SharePointResource[] resources;
    final readonly & string apiVersion;
    final http:Client httpClient;

    # Initialises the data loader.
    #
    # + resources - SharePoint resources to load
    # + config - HTTP and auth configuration
    # + return - an `ai:Error` if the HTTP client cannot be created
    public isolated function init(SharePointResource[] resources, *SharePointConfig config)
            returns Error? {
        self.resources = resources.cloneReadOnly();
        self.apiVersion = config.apiVersion;
        http:ClientConfiguration clientConfig = toClientConfig(config, config.accessToken);
        http:Client|http:Error httpClient = new (config.baseUrl, clientConfig);
        if httpClient is http:Error {
            return error Error("Failed to create SharePoint HTTP client: " + httpClient.message(),
                httpClient);
        }
        self.httpClient = httpClient;
    }

    # Loads documents from the configured resources.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = [];
        foreach SharePointResource res in self.resources {
            check self.loadResource(res, documents);
        }
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }

    private isolated function loadResource(SharePointResource res, Document[] documents)
            returns Error? {
        if res.kind == "folder" {
            SharePointItem[] children = check self.fetchFolderChildren(res.siteId, res.itemId);
            foreach SharePointItem child in children {
                if child?.folder is map<json> {
                    if res.recursive {
                        check self.loadResource(
                            {siteId: res.siteId, itemId: child.id, kind: "folder", recursive: true},
                            documents);
                    }
                    continue;
                }
                check self.loadResource(
                    {siteId: res.siteId, itemId: child.id, kind: "file"}, documents);
            }
            return;
        }
        Document doc = check self.loadFile(res.siteId, res.itemId);
        documents.push(doc);
    }

    private isolated function loadFile(string siteId, string itemId) returns Document|Error {
        SharePointItem meta = check self.fetchMetadata(siteId, itemId);
        string mimeType = "";
        map<json>? fileInfo = meta?.file;
        if fileInfo is map<json> {
            json|error mt = fileInfo["mimeType"];
            if mt is string {
                mimeType = mt;
            }
        }
        string path = string `/${self.apiVersion}/sites/${siteId}/drive/items/${itemId}/content`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `SharePoint download failed for ${itemId}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode < 200 || resp.statusCode >= 300 {
            return error Error(string `SharePoint download returned HTTP ${resp.statusCode} for ${itemId}`);
        }
        byte[]|http:ClientError bytes = resp.getBinaryPayload();
        if bytes is http:ClientError {
            return error Error("Failed to read SharePoint payload: " + bytes.message(), bytes);
        }
        string nameHint = meta?.name ?: itemId;
        return buildDocumentFromBytes(bytes, mimeType, nameHint);
    }

    private isolated function fetchMetadata(string siteId, string itemId)
            returns SharePointItem|Error {
        string path = string `/${self.apiVersion}/sites/${siteId}/drive/items/${itemId}`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `SharePoint metadata failed for ${itemId}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode != 200 {
            return error Error(string `SharePoint metadata returned HTTP ${resp.statusCode} for ${itemId}`);
        }
        json|http:ClientError payload = resp.getJsonPayload();
        if payload is http:ClientError {
            return error Error("SharePoint metadata is not JSON: " + payload.message(), payload);
        }
        SharePointItem|error item = payload.cloneWithType(SharePointItem);
        if item is error {
            return error Error("SharePoint metadata shape mismatch: " + item.message(), item);
        }
        return item;
    }

    private isolated function fetchFolderChildren(string siteId, string folderId)
            returns SharePointItem[]|Error {
        string path = string `/${self.apiVersion}/sites/${siteId}/drive/items/${folderId}/children`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `SharePoint listing failed for ${folderId}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode != 200 {
            return error Error(string `SharePoint listing returned HTTP ${resp.statusCode}`);
        }
        json|http:ClientError payload = resp.getJsonPayload();
        if payload is http:ClientError {
            return error Error("SharePoint listing is not JSON: " + payload.message(), payload);
        }
        SharePointListing|error listing = payload.cloneWithType(SharePointListing);
        if listing is error {
            return error Error("SharePoint listing shape mismatch: " + listing.message(), listing);
        }
        return listing.value;
    }
}

type SharePointItem record {
    string id;
    string name?;
    map<json> file?;
    map<json> folder?;
};

type SharePointListing record {|
    SharePointItem[] value;
|};

// =============================================================================
// SalesforceDataLoader (ContentVersion files)
// =============================================================================

# Configuration for `SalesforceDataLoader`.
public type SalesforceConfig record {|
    *CloudHttpConfig;
    # OAuth2 bearer token issued for the Salesforce org
    string accessToken;
    # Org instance URL (e.g., `https://mycompany.my.salesforce.com`)
    string instanceUrl;
    # REST API version segment, e.g., `v60.0`
    string apiVersion = "v60.0";
|};

# Loads documents from Salesforce ContentVersion records.
# Each ContentVersion ID is resolved to its `VersionData` binary payload and
# parsed via the file's extension / `FileType`.
public isolated class SalesforceDataLoader {
    *DataLoader;
    final readonly & string[] contentVersionIds;
    final readonly & string apiVersion;
    final http:Client httpClient;

    # Initialises the data loader.
    #
    # + contentVersionIds - Salesforce ContentVersion record IDs to load
    # + config - HTTP and auth configuration
    # + return - an `ai:Error` if the HTTP client cannot be created
    public isolated function init(string[] contentVersionIds, *SalesforceConfig config)
            returns Error? {
        self.contentVersionIds = contentVersionIds.cloneReadOnly();
        self.apiVersion = config.apiVersion;
        http:ClientConfiguration clientConfig = toClientConfig(config, config.accessToken);
        http:Client|http:Error httpClient = new (config.instanceUrl, clientConfig);
        if httpClient is http:Error {
            return error Error("Failed to create Salesforce HTTP client: " + httpClient.message(),
                httpClient);
        }
        self.httpClient = httpClient;
    }

    # Loads each ContentVersion's binary payload as a Document.
    # + return - document or an array of documents, or an `ai:Error` if the loading fails
    public isolated function load() returns Document[]|Document|Error {
        Document[] documents = [];
        foreach string id in self.contentVersionIds {
            documents.push(check self.loadOne(id));
        }
        if documents.length() == 1 {
            return documents[0];
        }
        return documents;
    }

    private isolated function loadOne(string id) returns Document|Error {
        SalesforceContentVersion meta = check self.fetchMetadata(id);
        string path = string `/services/data/${self.apiVersion}/sobjects/ContentVersion/${id}/VersionData`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `Salesforce VersionData fetch failed for ${id}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode < 200 || resp.statusCode >= 300 {
            return error Error(string `Salesforce VersionData returned HTTP ${resp.statusCode} for ${id}`);
        }
        byte[]|http:ClientError bytes = resp.getBinaryPayload();
        if bytes is http:ClientError {
            return error Error("Failed to read VersionData payload: " + bytes.message(), bytes);
        }
        // Response Content-Type is authoritative; otherwise rebuild a synthetic name
        // from Title + FileExtension so extension-based detection works.
        string contentType = resp.getContentType();
        string fileName = meta.Title + "." + meta.FileExtension.toLowerAscii();
        return buildDocumentFromBytes(bytes, contentType, fileName);
    }

    private isolated function fetchMetadata(string id) returns SalesforceContentVersion|Error {
        string fields = "Title,FileExtension,FileType";
        string path = string `/services/data/${self.apiVersion}/sobjects/ContentVersion/${id}?fields=${fields}`;
        http:Response|http:ClientError resp = self.httpClient->get(path);
        if resp is http:ClientError {
            return error Error(string `Salesforce metadata fetch failed for ${id}: ${resp.message()}`,
                resp);
        }
        if resp.statusCode != 200 {
            return error Error(string `Salesforce metadata returned HTTP ${resp.statusCode} for ${id}`);
        }
        json|http:ClientError payload = resp.getJsonPayload();
        if payload is http:ClientError {
            return error Error("Salesforce metadata is not JSON: " + payload.message(), payload);
        }
        SalesforceContentVersion|error meta = payload.cloneWithType(SalesforceContentVersion);
        if meta is error {
            return error Error("Salesforce metadata shape mismatch: " + meta.message(), meta);
        }
        return meta;
    }
}

type SalesforceContentVersion record {|
    string Title;
    string FileExtension;
    string FileType?;
|};
