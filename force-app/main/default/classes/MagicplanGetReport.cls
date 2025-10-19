// Invocable Apex action to fetch a report PDF for a magicplan project.
// Optionally downloads the file and stores it as a Salesforce File on a record.
public with sharing class MagicplanGetReport {

    public class Request {
        // The magicplan project ID returned by MagicplanCreateProject
        @InvocableVariable(required=true) public String projectId;

        // The type/label to look for (e.g., 'Report PDF'); defaults to 'Report PDF'
        @InvocableVariable public String reportType;

        // Named Credential override; defaults to 'Magicplan'
        @InvocableVariable public String namedCredentialName;

        // If provided, the report will be downloaded and saved as a ContentVersion linked to this record.
        // If not provided, we will try to find a MagicPlan_Project__c with MagicPlan_Project_Id__c = projectId and attach there.
        @InvocableVariable public Id linkToRecordId;

        // The title of the uploaded file; defaults to the file name returned by magicplan
        @InvocableVariable public String fileTitle;

        // If true, any existing file with the same title on the record will be removed before saving
        @InvocableVariable public Boolean replaceExisting;
    }

    public class Result {
        // Populated when the file is saved
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;

        // Always populated with the presigned download URL from magicplan (if a matching file is found)
        @InvocableVariable public String downloadUrl;

        // HTTP status code from listing project files
        @InvocableVariable public Integer statusCode;

        // Set when an error occurs
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(
        label='Magicplan — Get Report PDF'
        description='Fetches the latest report PDF (by type/label) for a Magicplan project and optionally saves it as a Salesforce File.'
    )
    public static List<Result> getReportPdfs(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) return results;

        Http http = new Http();

        for (Request req : requests) {
            Result res = new Result();
            try {
                if (String.isBlank(req.projectId)) {
                    res.errorMessage = 'projectId is required.';
                    results.add(res);
                    continue;
                }

                String namedCred = String.isBlank(req.namedCredentialName) ? 'Magicplan' : req.namedCredentialName;

                // 1) List project files
                String endpoint = 'callout:' + namedCred + '/projects/' + EncodingUtil.urlEncode(req.projectId, 'UTF-8') + '/files';
                HttpRequest listReq = new HttpRequest();
                listReq.setMethod('GET');
                listReq.setHeader('Accept', 'application/json');
                listReq.setEndpoint(endpoint);

                HttpResponse listRes = http.send(listReq);
                res.statusCode = listRes.getStatusCode();

                if (listRes.getStatusCode() < 200 || listRes.getStatusCode() >= 300) {
                    res.errorMessage = 'Failed to list files. HTTP ' + listRes.getStatusCode() + ' ' + listRes.getStatus() +
                                       '. Body: ' + listRes.getBody();
                    results.add(res);
                    continue;
                }

                // 2) Parse response into a list of file maps
                List<Object> fileObjs = parseFilesArray(listRes.getBody());

                // 3) Pick the first file that matches requested "reportType" (defaults to "Report PDF")
                String desired = String.isBlank(req.reportType) ? 'Report PDF' : req.reportType;
                Map<String,Object> chosen = pickMatchingFile(fileObjs, desired);

                if (chosen == null) {
                    res.errorMessage = 'No file matching type "' + desired + '" found for project ' + req.projectId;
                    results.add(res);
                    continue;
                }

                String downloadUrl = (String) chosen.get('download_url');
                res.downloadUrl = downloadUrl;

                // 4) Optionally download and attach as ContentVersion
                Id target = req.linkToRecordId;
                if (target == null) {
                    // Try to auto-resolve a MagicPlan_Project__c to attach to
                    List<MagicPlan_Project__c> matches = [
                        SELECT Id
                        FROM MagicPlan_Project__c
                        WHERE MagicPlan_Project_Id__c = :req.projectId
                        LIMIT 2
                    ];
                    if (matches.size() == 1) target = matches[0].Id;
                }

                if (target != null && !String.isBlank(downloadUrl)) {
                    // Download the file (Note: presigned URL must be allowed by Remote Site or use API-native download endpoint if available)
                    HttpRequest dlReq = new HttpRequest();
                    dlReq.setMethod('GET');
                    dlReq.setEndpoint(downloadUrl);
                    HttpResponse dlRes = http.send(dlReq);

                    if (dlRes.getStatusCode() < 200 || dlRes.getStatusCode() >= 300) {
                        res.errorMessage = 'Failed to download file. HTTP ' + dlRes.getStatusCode() + ' ' + dlRes.getStatus();
                        results.add(res);
                        continue;
                    }

                    Blob fileBlob = dlRes.getBodyAsBlob();

                    // Optional dedupe by title
                    String title = !String.isBlank(req.fileTitle)
                        ? req.fileTitle
                        : (String) chosen.get('file_name');

                    if (req.replaceExisting == true && !String.isBlank(title)) {
                        List<ContentDocumentLink> existing = [
                            SELECT Id, ContentDocumentId
                            FROM ContentDocumentLink
                            WHERE LinkedEntityId = :target
                            AND ContentDocument.LatestPublishedVersion.Title = :title
                        ];
                        if (!existing.isEmpty()) {
                            delete existing; // unlink (and delete doc if this was the last link)
                        }
                    }

                    ContentVersion cv = new ContentVersion();
                    cv.Title = (String.isBlank(title) ? 'Magicplan File' : title);
                    cv.PathOnClient = cv.Title;
                    cv.VersionData = fileBlob;
                    cv.FirstPublishLocationId = target;
                    insert cv;

                    cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
                    res.contentVersionId = cv.Id;
                    res.contentDocumentId = cv.ContentDocumentId;
                }

            } catch (Exception e) {
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }

        return results;
    }

    // ---- Helpers ----

    @TestVisible
    private static List<Object> parseFilesArray(String body) {
        Object parsed = JSON.deserializeUntyped(body);
        if (parsed instanceof List<Object>) return (List<Object>) parsed;
        if (parsed instanceof Map<String,Object>) {
            Map<String,Object> m = (Map<String,Object>) parsed;
            Object f = m.get('files'); if (f instanceof List<Object>) return (List<Object>) f;
            Object d = m.get('data');  if (d instanceof List<Object>) return (List<Object>) d;
        }
        return new List<Object>();
    }

    @TestVisible
    private static Map<String,Object> pickMatchingFile(List<Object> files, String desired) {
        String needle = String.isBlank(desired) ? '' : desired.toLowerCase();
        for (Object o : files) {
            if (!(o instanceof Map<String,Object>)) continue;
            Map<String,Object> f = (Map<String,Object>) o;
            String name   = (String) f.get('file_name');
            String type   = (String) f.get('type');
            String format = (String) f.get('format');

            if (!String.isBlank(needle)) {
                if (!String.isBlank(type)   && type.toLowerCase().contains(needle))   return f;
                if (!String.isBlank(format) && format.toLowerCase().contains(needle)) return f;
                if (!String.isBlank(name)   && name.toLowerCase().contains(needle))   return f;
            } else {
                return f;
            }
        }
        return null;
    }
}
