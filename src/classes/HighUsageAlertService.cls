/**
 * Created by byarsawi on 5/15/2018.
 */

public with sharing class HighUsageAlertService {

    private final static Id CASERECORDTYPEID = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Public Works Case').getRecordTypeId();
    private final static Id WORECORDTYPEID = Schema.SObjectType.WorkOrder.getRecordTypeInfosByName().get('Public Works Work Order').getRecordTypeId();
    private final static Integer NEWCASEDAYSLIMIT = -2;
    private final static Map <Id, ActionCode__c> ACTIONCODEMAP = new Map<Id,ActionCode__c>(
            [SELECT Id, Name, Case_Status__c, Work_Order__c, Send_Email__c, Contacted__c, Work_Type__c, Work_Type__r.Price_Book__c
            FROM ActionCode__c]);
    private final static EmailTemplate TEMPLATEID =
            [SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'High_Usage_Notification'];
    private final static ActionCode__c NEVERSEENID =
            [SELECT Id
            FROM ActionCode__c
            WHERE Name = 'Never-Seen'];
    private  final Id HUACASEISSUEID =
            [SELECT Id
            FROM Case_Issue__c
            WHERE Name = 'High Usage Alert'][0].Id;
    private final Id RECLAIMEDISSUEID =
            [SELECT Id
            FROM Case_Issue__c
            WHERE Name = 'Reclaimed Water High Usage Alert'][0].Id;

    public void beforeInsert(List<HighUsageAlert__c> newHighUsageAlertList){
        for(HighUsageAlert__c hua : newHighUsageAlertList){
            if(hua.Case__c == null){
                String caseIssueId = hua.Service__c == 'RW' ? RECLAIMEDISSUEID : HUACASEISSUEID;
                //set appearance count to 1 to start.  This can change if there is already a case for this account.
                hua.Appearance_Count__c = 1;

                Account account =
                        [SELECT Id,
                                (SELECT Id, Email
                                FROM Contacts Limit 1)
                        FROM Account
                        WHERE CID__c = :hua.CID__c][0];
                String accountServiceId =
                        [SELECT Id
                        FROM Account_Service__c
                        WHERE LID__c = :hua.LID__c And Service_Type__c = :hua.Service__c][0].Id;
                String serviceAddressId =
                        [SELECT Id
                        FROM Service_Address__c
                        WHERE Location_ID__c = :hua.LID__C][0].Id;
                List<Case> caseList =
                        [SELECT Id, CaseNumber, Status, Service_Address__c,
                                (SELECT Id
                                FROM WorkOrders)
                        FROM Case
                        WHERE CaseIssue__c = :caseIssueId AND AccountId = :account.Id AND Service_Address__c = :serviceAddressId
                            AND Id IN
                                (SELECT Case__c
                                FROM HighUsageAlert__c
                                WHERE Service__c = :hua.Service__c AND Meter_Number__c = :hua.Meter_Number__c)
                        ORDER BY CaseNumber DESC];

                //no cases for this account service
                //create new case
                if(caseList.size() <= 0){
                    createCase(hua, account, serviceAddressId, caseIssueId);
                } else {
                    //get list of leaks attached to the case with the same account service as the incoming leak
                    List<HighUsageAlert__c> huaList = [Select Id, Case__c, Meter_Number__c, ActionCode__c, Contacted__c, CreatedDate, Service__c, Action_Code__r.Id, Action_Code__r.Name From HighUsageAlert__c Where Case__c = :caseList[0].Id Order By Name Desc];
                    //if there are no cases on the current account service or
                    //if the last previous leak on the case is at least NEWCASEDAYSLIMIT days old then create a new case
                    //The subtracting of two horus is to make sure that there is no problem with the time leaks are imported or
                    //if the incoming leak has the same account but a different meter number than leaks on the case.
                    if(huaList.size() <= 0 || huaList[0].CreatedDate < dateTime.now().addDays(NEWCASEDAYSLIMIT).addHours(-2)){
                        createCase(hua, account, serviceAddressId, caseIssueId);
                    } else {
                        //add leak to current case and update the counts on the leak.
                        hua.Case__c = huaList[0].Case__c;
                        updateCounts(hua, huaList);
                        //if there are no work orders on a case and it hasn't been banned to the reoccuring queue then change the status back to new
                        if(caseList[0].WorkOrders.size() <= 0 || huaList[0].ActionCode__r.Name != 'Reoccurring Client'){
                            caseList[0].Status = 'New';
                            update caseList;
                        }
                    }
                }
                hua.Account_Service__c = accountServiceId;
            }
        }
    }


    /** PRIVATE METHODS **/

    private void createCase(HighUsageAlert__c hua, Account account, String serviceAddressId, String caseIssueId){
        System.debug('creating a case');
        Case theCase = new Case(
                AccountId = account.Id,
                ServiceAddress__c = serviceAddressId,
                CaseIssue__c = caseIssueId,
                Origin = 'TOC',
                Status = 'New',
                RecordTypeId = CASERECORDTYPEID
                //Do_not_send_email_notification__c = true
        );
        if(account.Contacts.size() > 0){
            theCase.ContactId = account.Contacts[0].Id;
        }
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule= true;
        theCase.setOptions(dmo);
        insert theCase;

        hua.Case__c = theCase.Id;
    }

    //Update the incoming counts based on data from salesforce
    private void updateCounts(HighUsageAlert__c hua, List<HighUsageAlert__c> huaList){
        hua.Appearance_Count__c = huaList.size() + 1;

        Integer contactCount = 0;
        Integer noContactCount = 0;
        Integer workloadCount = 0;
        //loop over cases to determine each count
        for(HighUsageAlert__c h :huaList){
            if(h.Contacted__c){
                contactCount++;
            } else if (h.ActionCode__c != null && ACTIONCODEMAP.get(h.ActionCode__c).Name == 'No Contact-Decision') {
                noContactCount++;
            } else {
                workloadCount++;
            }
        }
        hua.Contact_Count__c = contactCount;
        hua.No_Contact_Count__c = noContactCount;
        hua.No_Contact_Workload__c = workloadCount;
    }

    private WorkOrder setWorkOrder(Case huaCase, ActionCode__c ac){
        WorkOrder newWO = new WorkOrder(
                StartDate = Datetime.now(),
                EndDate = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0)),
                //Due_Date__c = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0)),
                AccountId = huaCase.AccountId,
                CaseId = huaCase.Id,
                RecordTypeId = WORECORDTYPEID,
                AssetId = huaCase.AssetId,
                //Service_Address__c = huaCase.ServiceAddress__c,
                WorkTypeId = ac.Work_Type__c,
                Pricebook2Id = ac.Work_Type__r.Price_Book__c
        );
        System.debug('WORK ORDER BEING INSERTED:');
        System.debug(newWO);


        return newWO;
    }

    private void sendEmailToContact(HighUsageAlert__c hua, Case huaCase, String emailAddress) {
        if(huaCase.ContactId != null && emailAddress != null){
            Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(TEMPLATEID.Id, huaCase.ContactId, hua.Id);
            List<String> toAddress = new List<String>();
            toAddress.add(emailAddress);
            email.setTreatTargetObjectAsRecipient(false);
            email.setToAddresses(toAddress);
            email.setSenderDisplayName('Town of Cary Public Works');
            system.debug(email);
            List<Messaging.SendEmailResult> result = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            if(result[0].isSuccess()){
                hua.Contacted__c = true;
            }
        }
    }

    private List<Case> getCases(List<HighUsageAlert__c> newHighUsageAlertList){
        List<String> caseIds = new List<String>();
        for(HighUsageAlert__c hua : newHighUsageAlertList){
            caseIds.add(hua.Case__c);
        }
        List<Case> results =
                [SELECT Id, Department__c, Division__c, AssetId, Due_Date__c, RequestedDate__c, CreatedDate, Status, RecordTypeId,
                    AccountId, ServiceAddress__c, ContactId
                FROM Case
                WHERE Id IN :caseIds];
        return results;
    }

    private List<Contact> getContacts(List<Case> cases){
        List<String> contactIds = new List<String>();
        for(Case c : cases){
            contactIds.add(c.ContactId);
        }
        return [Select Id, Email From Contact where Id in :contactIds];
    }
}