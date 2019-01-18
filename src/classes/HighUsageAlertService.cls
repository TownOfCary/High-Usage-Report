/**
 * Created by byarsawi on 5/15/2018.
 */

public with sharing class HighUsageAlertService {

    private final static Id CASERECORDTYPEID = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Information Request').getRecordTypeId();
    private final static Id WORECORDTYPEID = Schema.SObjectType.WorkOrder.getRecordTypeInfosByName().get('General Work Order').getRecordTypeId();
    private final static Integer NEWCASEDAYSLIMIT = -2;
    private final static Map <Id, Action_Code__c> ACTIONCODEMAP = new Map<Id,Action_Code__c>(
            [SELECT Id, Name, Case_Status__c, Work_Order__c, Send_Email__c, Contacted__c, Work_Type__c, Work_Type__r.pwut_toc__Price_Book__c
            FROM Action_Code__c]);
//    private final static EmailTemplate TEMPLATEID =
//            [SELECT Id
//            FROM EmailTemplate
//            WHERE DeveloperName = 'High_Usage_Notification'];
    private final static Action_Code__c NEVERSEENID =
            [SELECT Id
            FROM Action_Code__c
            WHERE Name = 'Never-Seen'];
    private  final static Id HUACASEISSUEID =
            [SELECT Id
            FROM base_toc__Case_Issue__c
            WHERE Name = 'High Usage Alert'][0].Id;
    private final static Id RECLAIMEDISSUEID =
            [SELECT Id
            FROM base_toc__Case_Issue__c
            WHERE Name = 'Reclaimed Water High Usage Alert'][0].Id;

    public static void beforeInsert(List<High_Usage_Alert__c> newHighUsageAlertList) {
        for (High_Usage_Alert__c hua : newHighUsageAlertList) {
            if (hua.Case__c == null) {
                String caseIssueId = hua.Service__c == 'RW' ? RECLAIMEDISSUEID : HUACASEISSUEID;
                //set appearance count to 1 to start.  This can change if there is already a case for this account.
                hua.Appearance_Count__c = 1;

                Account account =
                        [SELECT Id,
                                (SELECT Id, Email
                                FROM Contacts Limit 1)
                        FROM Account
                        WHERE base_toc__CID__c = :hua.CID__c][0];
                String accountServiceId =
                        [SELECT Id
                        FROM base_toc__Account_Service__c
                        WHERE base_toc__LID__c = :hua.LID__c And base_toc__Service_Type__c = :hua.Service__c][0].Id;
                String serviceAddressId =
                        [SELECT Id
                        FROM base_toc__Service_Address__c
                        WHERE base_toc__LID__c = :hua.LID__C][0].Id;
                List<Case> caseList =
                        [SELECT Id, CaseNumber, Status, base_toc__Service_Address__c,
                                (SELECT Id
                                FROM WorkOrders)
                        FROM Case
                        WHERE base_toc__Case_Issue__c = :caseIssueId AND AccountId = :account.Id AND base_toc__Service_Address__c = :serviceAddressId
                            AND Id IN
                                (SELECT Case__c
                                FROM High_Usage_Alert__c
                                WHERE Service__c = :hua.Service__c AND Meter_Number__c = :hua.Meter_Number__c)
                        ORDER BY CaseNumber DESC];

                //no cases for this account service
                //create new case
                if (caseList.size() <= 0){
                    createCase(hua, account, serviceAddressId, caseIssueId);
                } else {
                    //get list of leaks attached to the case with the same account service as the incoming leak
                    List<High_Usage_Alert__c> huaList =
                            [SELECT Id, Case__c, Meter_Number__c, Action_Code__c, Contacted__c, CreatedDate, Service__c, Action_Code__r.Id, Action_Code__r.Name
                            FROM High_Usage_Alert__c
                            WHERE Case__c = :caseList[0].Id
                            ORDER BY Name Desc];
                    //if there are no cases on the current account service or
                    //if the last previous leak on the case is at least NEWCASEDAYSLIMIT days old then create a new case
                    //The subtracting of two horus is to make sure that there is no problem with the time leaks are imported or
                    //if the incoming leak has the same account but a different meter number than leaks on the case.
                    if (huaList.size() <= 0 || huaList[0].CreatedDate < dateTime.now().addDays(NEWCASEDAYSLIMIT).addHours(-2)) {
                        createCase(hua, account, serviceAddressId, caseIssueId);
                    } else {
                        //add leak to current case and update the counts on the leak.
                        hua.Case__c = huaList[0].Case__c;
                        updateCounts(hua, huaList);
                        //if there are no work orders on a case and it hasn't been banned to the reoccuring queue then change the status back to new
                        if (caseList[0].WorkOrders.size() <= 0 || huaList[0].Action_Code__r.Name != 'Reoccurring Client') {
                            caseList[0].Status = 'New';
                            update caseList;
                        }
                    }
                }
                hua.Account_Service__c = accountServiceId;
            }
        }
    }

    public static void beforeUpdate(List<High_Usage_Alert__c> newHighUsageAlertList){
        Map<Id, Case> caseMap = new Map<Id, Case>(getCases(newHighUsageAlertList));
        //Map<Id, Contact> contactMap = new Map<Id,Contact>(getContacts(caseMap.values()));
        List<WorkOrder> workOrdersToAdd = new List<WorkOrder>();
        List<Case> casesToUpdate = new List<Case>();
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule = true;

        for (High_Usage_Alert__c hua : newHighUsageAlertList) {
            System.debug(hua);
            if (hua.Action_Code__c == null || hua.Action_Code__c == NEVERSEENID.Id) {
                continue;
            }
            Case huaCase = caseMap.get(hua.Case__c);
            Action_Code__c actionCode = ACTIONCODEMAP.get(hua.Action_Code__c);
            system.debug(actionCode);
            huaCase.Status = actionCode.Case_Status__c;
            hua.Contacted__c = actionCode.Contacted__c;
            if(actionCode.Work_Order__c) {
                huaCase.base_toc__Due_Date__c = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0));
                huaCase.base_toc__Earliest_Start_Date__c = Datetime.now();
                workOrdersToAdd.add(setWorkOrder(huaCase, actionCode));
            }

            huaCase.setOptions(dmo);
            casesToUpdate.add(huaCase);
        }
        Database.update(casesToUpdate);
        insert workOrdersToAdd;
    }


    /** PRIVATE METHODS **/
    private static void createCase(High_Usage_Alert__c hua, Account account, String serviceAddressId, String caseIssueId) {
        System.debug('creating a case');
        Case theCase = new Case(
                AccountId = account.Id,
                base_toc__Service_Address__c = serviceAddressId,
                base_toc__Case_Issue__c = caseIssueId,
                Origin = 'TOC',
                Status = 'New',
                RecordTypeId = CASERECORDTYPEID
                //Do_not_send_email_notification__c = true
        );
        if (account.Contacts.size() > 0) {
            theCase.ContactId = account.Contacts[0].Id;
        }
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule= true;
        theCase.setOptions(dmo);
        insert theCase;

        hua.Case__c = theCase.Id;
    }

    //Update the incoming counts based on data from salesforce
    private static void updateCounts(High_Usage_Alert__c hua, List<High_Usage_Alert__c> huaList) {
        hua.Appearance_Count__c = huaList.size() + 1;

        Integer contactCount = 0;
        Integer noContactCount = 0;
        Integer workloadCount = 0;
        //loop over cases to determine each count
        for (High_Usage_Alert__c h :huaList) {
            if (h.Contacted__c) {
                contactCount++;
            } else if (h.Action_Code__c != null && ACTIONCODEMAP.get(h.Action_Code__c).Name == 'No Contact-Decision') {
                noContactCount++;
            } else {
                workloadCount++;
            }
        }
        hua.Contact_Count__c = contactCount;
        hua.No_Contact_Count__c = noContactCount;
        hua.No_Contact_Workload__c = workloadCount;
    }

    private static WorkOrder setWorkOrder(Case huaCase, Action_Code__c ac) {
        WorkOrder newWO = new WorkOrder(
                StartDate = Datetime.now(),
                EndDate = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0)),
                pwut_toc__Due_Date__c = Datetime.newInstance(Date.today(), Time.newInstance(23,59,59,0)),
                AccountId = huaCase.AccountId,
                CaseId = huaCase.Id,
                RecordTypeId = WORECORDTYPEID,
                AssetId = huaCase.AssetId,
                pwut_toc__Service_Address__c = huaCase.base_toc__Service_Address__c,
                WorkTypeId = ac.Work_Type__c,
                Pricebook2Id = ac.Work_Type__r.pwut_toc__Price_Book__c
        );
        System.debug('WORK ORDER BEING INSERTED:');
        System.debug(newWO);

        return newWO;
    }

    private static List<Case> getCases(List<High_Usage_Alert__c> newHighUsageAlertList) {
        system.debug('In Get Cases');
        List<String> caseIds = base_toc.ArrayUtils.getField(newHighUsageAlertList, PackageUtils.namespace + '__Case__c');
        system.debug(caseIds);
        List<Case> results =
                [SELECT Id, AssetId, base_toc__Due_Date__c, CreatedDate, Status, RecordTypeId,
                    AccountId, base_toc__Service_Address__c, ContactId
                FROM Case
                WHERE Id IN :caseIds];
        system.debug(results);
        return results;
    }

    private static List<Contact> getContacts(List<Case> cases) {
        List<String> contactIds =  base_toc.ArrayUtils.getField(cases, PackageUtils.namespace + '__ContactId');
        List<Contact> results =
                [SELECT Id, Email
                FROM Contact
                WHERE Id IN :contactIds];
        return results;
    }

}