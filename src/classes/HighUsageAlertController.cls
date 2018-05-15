/**
 * Created by byarsawi on 5/14/2018.
 */

public with sharing class HighUsageAlertController {

    //the currently visible list of cases displayed on the page.  This changes based on display amount
    //and based on the current page they are looking at.
    public List<HighUsageAlertWrapper> huaReportSetController { get; set; }
    public List<SelectOption> serviceSearchOptions { get; private set; }
    public String sortColumn { get; set; }
    public Boolean selected { get; set; }
    public String serviceSearch { get; set; }
    public String caseStatus { get; set; }
    public Integer recordLBound { get; set; }

    public Integer recordUBound {
        get {
            Integer tmp = this.currentStartNumber + Integer.valueOf(this.displayAmount);
            return (tmp > this.totalCasesForPagination) ? this.totalCasesForPagination : tmp;
        }
        set;
    }

    //variables for selecting workers for the day
    public List<String> gridBuilderServiceList { get; set; }
    public Map<String, Integer> caseServiceTotalAmounts { get; set; }
    public List<SelectOption> userList { get; set; }
    public List<SelectOption> unselectedWorkers { get; set; }
    public List<String> workersToAdd { get; set; }
    public List<HighUsageWorker> selectedWorkers { get; set; }
    public Boolean casesAssigned {get; private set;}
    public String theUserId { get; set; }
    public Integer currentStartNumber { get; set; }
    public Integer totalCasesForPagination { get; set; }

    //sets how many rows are shown on the page.  If no value assigned default to 25
    public String displayAmount {
        get {
            if (this.displayAmount == null ){
                this.displayAmount ='25';
            }
            return this.displayAmount;
        }
        set;
    }

    public List<SelectOption> getRowAmount() {
        List<SelectOption> options = new List<SelectOption>();
        options.add(new SelectOption('10','10'));
        options.add(new SelectOption('25','25'));
        options.add(new SelectOption('50','50'));
        options.add(new SelectOption('100','100'));
        return options;
    }

    //Set values for types of cases user wishes to see.
    public List<SelectOption> caseStatusList {
        get{
            return getPickValues(new Case(), 'Status', NULL);
        }
        set;
    }

    //private variables
    private Map<String, Integer> workerCaseInitMap { get; set; }
    private List<SelectOption> actionCodeOptions { get; set; }
    private List<SelectOption> actionCodeOptionsNoEmail { get; set; }
    private String currentSortColumn { get; set; }
    private Boolean sortOrder { get; set; }

    //private final variables
    private  final Id HUACASEISSUEID =
            [SELECT Id
            FROM Case_Issue__c
            WHERE Name = 'High Usage Alert'][0].Id;
    private final Id RECLAIMEDISSUEID =
            [SELECT Id
            FROM Case_Issue__c
            WHERE Name = 'Reclaimed Water High Usage Alert'][0].Id;
    private final Id HIGHUSAGEPERMISSION =
            [SELECT Id
            FROM PermissionSet
            WHERE Name = 'High_Usage_Report'][0].Id;
    private final Id TOCAPIUSERID =
            [SELECT Id
            FROM User
            WHERE Alias = 'tocapi'][0].Id;
    private final ActionCode__c NEVERSEENAC =
            [SELECT Id, Name, Send_Email__c
            FROM ActionCode__c
            WHERE Name = 'Never-Seen'];

    public HighUsageAlertController(){
        //initialize varriables
        //determines if cases have already been assigned to the users, assume fales on each load until checked
        this.casesAssigned = false;
        //list of cases to be displayed on the table
        this.huaReportSetController = new List<HighUsageAlertWrapper>();
        //list of users who are assigned as workers on the current list of cases
        this.userList = new List<SelectOption>();
        //lsit of users not assigned to any case, initially is a list of all users in utility accounts
        this.unselectedWorkers = new List<SelectOption>();
        //Sleected users on the unselected user list who are about to become selected users.
        this.workersToAdd = new List<String>();
        //list of workers currently selected to work the report before being assigned cases
        this.selectedWorkers = new List<HighUsageWorker>();
        //user id selected in the drop down list to see their currently assigned cases
        this.theUserId = UserInfo.getUserId();
        //Column we intially sort the list of cases by.
        this.currentSortColumn = 'HighUsageAlert__c.Percent_Change__c';

        this.caseStatus = 'New'; 		//default case status that is displayed
        this.displayAmount = '25';		//default number of cases shown per page
        this.currentStartNumber = 0;		//Start number for pagination Array is 0 based
        this.totalCasesForPagination = 0;	//Total number of cases in list for pagination
        this.sortOrder = true;		//Flag for DESC=true ASC=false
        this.recordLBound = 1;
        this.recordUBound = this.currentStartNumber + Integer.valueOf(this.displayAmount) - 1;

        //set list of services for searching
        this.serviceSearchOptions = new List<SelectOption>();
        this.serviceSearchOptions.add(new SelectOption('All', 'All'));

        buildServiceList();

        //get list of all action codes and place them in Select Option List for drop down
        //this is only used by the actual report page, but I'll load it in the constructor to save time on each page refresh
        String query = 'Order__c != null';
        Framework.Selector actionCodes = new Framework.Selector(ActionCode__c.getSObjectType(), query);
        this.actionCodeOptions = new List<SelectOption>();
        this.actionCodeOptions.add(new SelectOption('', ''));
        this.actionCodeOptions.addAll(actionCodes.selectOptions());

        query += ' AND Send_Email__c = false';
        Framework.Selector actionCodesNoEmail = new Framework.Selector(ActionCode__c.getSObjectType(), query);
        this.actionCodeOptionsNoEmail = new List<SelectOption>();
        this.actionCodeOptionsNoEmail.add(new SelectOption('', ''));
        this.actionCodeOptionsNoEmail.addAll(actionCodesNoEmail.selectOptions());

        this.casesAssigned = !casesToBeAssigned();
        if (this.casesAssigned) {
            fillUserList();
            this.setPageList();
        } else {
            //no cases have been assigned
            //get list of workers who have permission to work the list
            this.unselectedWorkers = retrieveUtilityAccountsUserList();
            //build up the map of the totals for each type of case
            buildCaseTotals();
        }
        system.debug('@@@@@@@@@@@Gridbuilder');
        system.debug(this.gridBuilderServiceList);
        system.debug(Logginglevel.INFO,this.caseServiceTotalAmounts);
        system.debug(this.huaReportSetController);
    }

    // Begin Public Page Reference functions
    public PageReference changeCaseList() {
        this.currentStartNumber = 0;
        this.recordLBound = this.currentStartNumber + 1;
        this.setPageList();
        return null;
    }

    public PageReference saveInlineChanges() {
        try {
            List<HighUsageAlert__c> huaChanges = new List<HighUsageAlert__c>();
            List<Case> caseChanges = new List<Case>();
            for (HighUsageAlertWrapper huaWrapper : this.huaReportSetController) {
                if (huaWrapper.isSelected) {
                    huaChanges.add(huaWrapper.theCase);
                    caseChanges.add(huaWrapper.theCase.Case__r);
                }
            }

            if (!caseChanges.isEmpty()) {
                upsert caseChanges;
            }
            if (!huaChanges.isEmpty()) {
                upsert huaChanges;
            }

            this.currentStartNumber = 0;
            this.recordLBound = this.currentStartNumber + 1;
            this.setPageList();
        } catch(System.DMLException e) {
            ApexPages.addMessages(e);
            System.debug(Logginglevel.INFO,e);
        }
        return null;
    }

    public PageReference closeRemaining() {
        try {
            ActionCode__c actionCode =
                [SELECT Id, Name, Case_Status__c
                FROM ActionCode__c
                WHERE Name = 'No Contact-Workload'][0];
            List<HighUsageAlert__c> updateQueue = new List<HighUsageAlert__c>();
            String query = 'ActionCode__c = null';
            Framework.Selector huas = new Framework.Selector(HighUsageAlert__c.getSObjectType(), query);
            for (HighUsageAlert__c hua : (List<HighUsageAlert__c>) huas.getAll()) {
                hua.ActionCode__c = actionCode.Id;
                updateQueue.add(hua);
            }
            update updateQueue;
            this.currentStartNumber = 0;
            this.recordLBound = this.currentStartNumber + 1;
            this.setPageList();
        } catch(System.DMLException e) {
            ApexPages.addMessages(e);
            System.debug(Logginglevel.INFO,e);
        }
        return null;
    }

    public PageReference reassignWorkers() {
        this.casesAssigned = false;
        buildServiceList();
        this.unselectedWorkers = retrieveUtilityAccountsUserList();
        //build up the map of the totals for each type of case
        reassignCaseTotals();
        return null;
    }

    public PageReference doSelect() {
        //until there is a contains() function a double loop will have to do.
        //I will have to look into the cost for this versus two database calls to reload both lists
        //The number of users maximum is fairly small for this page so the n^2 cost should not be a problem
        List<Integer> removeWorkers = new List<Integer>();
        for (String workerID : this.workersToAdd) {
            for (Integer i = 0; i < this.unselectedWorkers.size(); i++) {
                if (this.unselectedWorkers[i].getValue() == workerID) {
                    removeWorkers.add(i);
                }
            }
        }
        system.debug(removeWorkers);
        for (Integer i = removeWorkers.size() - 1; i >= 0; i--) {
            system.debug(removeWorkers[i]);
            system.debug(this.unselectedWorkers[removeWorkers[i]]);
            SelectOption tmp = this.unselectedWorkers.remove(removeWorkers[i]);
            this.selectedWorkers.add(new HighUsageWorker(tmp.getValue(), tmp.getLabel(), this.workerCaseInitMap.clone() ));
        }
        return null;
    }

    public PageReference doUnSelect() {
        List<Integer> workerSwitch = new List<Integer>();
        for (Integer i = 0; i < this.selectedWorkers.size(); i++) {
            if (this.selectedWorkers[i].isSelected) {
                workerSwitch.add(i);
            }
        }
        for (Integer i = workerSwitch.size() - 1; i >= 0; i--) {
            HighUsageWorker tmp = this.selectedWorkers.remove(workerSwitch[i]);
            this.unselectedWorkers.add(new SelectOption(tmp.userId, tmp.userName));
        }
        SelectOptionSorter.doSort(this.unselectedWorkers, SelectOptionSorter.FieldToSort.Label);
        return null;
    }

    public PageReference saveWorkerInfo() {
        Map<String, Integer> totalAssignedCases = new Map<String, Integer>();
        //huaReportWorkersList = new Map<Id, List<HighUsageAlertWrapper>>();
        for (HighUsageWorker huw : this.selectedWorkers) {
            for (String key : huw.numCases.keySet()) {
                if (totalAssignedCases.get(key) == null) {
                    totalAssignedCases.put(key, huw.numCases.get(key));
                } else {
                    totalAssignedCases.put(key, totalAssignedCases.get(key) + huw.numCases.get(key));
                }
            }
        }

        if (totalAssignedCases != this.caseServiceTotalAmounts) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
                    'Please make sure the total number of cases assigned to each user is equal'
                            + ' to the total number of cases in each category.'));
            return null;
        }

        Map<String, List<HighUsageAlert__c>> sameAccounts = getSameAccounts();
        assignSameAccountHUAs(sameAccounts);
        Map<String, List<HighUsageAlertWrapper>> huasByService = divideHUAs();


        List<HighUsageAlert__c> huasToUpdate = new List<HighUsageAlert__c>();
        Integer numAlreadyAssigned = 0;
        for (String key : huasByService.keySet()) {
            Integer workerIndex = 0;
            if (huasByService.get(key) != null) {
                System.debug(Logginglevel.INFO, huasByService.get(key).size());
            }
            while (huasByService.get(key) != null && !huasByService.get(key).isEmpty()) {
                //if we've run out of workers for this case or it is already assigned then skip to end and remove the case.
                if (workerIndex < this.selectedWorkers.size() && !sameAccounts.containsKey(huasByService.get(key)[0].theCase.CID__c)) {
                    //if the current worker has a case left assign owner to HUA, put in list to update and jump to end
                    if (this.selectedWorkers[workerIndex].numCases.get(key) > 0) {
                        huasByService.get(key)[0].theCase.OwnerID = this.selectedWorkers[workerIndex].userID;
                        huasToUpdate.add(huasByService.get(key)[0].theCase);
                        this.selectedWorkers[workerIndex].numCases.put(
                                key,
                                this.selectedWorkers[workerIndex].numCases.get(key) -1);
                    } else {
                        //get next worker index
                        do {
                            workerIndex++;
                        } while (workerIndex < this.selectedWorkers.size() && this.selectedWorkers[workerIndex].numCases.get(key) <= 0);
                        //This is a check for something that should never happen.
                        if (workerIndex >= this.selectedWorkers.size()) {
                            // I don't know what to do.
                            System.debug(Logginglevel.INFO, 'ERRRRRRRRRRRRRROOOOOOOOOOOOORRRRRR');
                        } else {
                            System.debug(Logginglevel.INFO, 'Id before change: ' + huasByService.get(key)[0].theCase.OwnerID);
                            //we have a new worker with cases to assign
                            huasByService.get(key)[0].theCase.OwnerID = this.selectedWorkers[workerIndex].userID;
                            huasToUpdate.add(huasByService.get(key)[0].theCase);
                            this.selectedWorkers[workerIndex].numCases.put(key, this.selectedWorkers[workerIndex].numCases.get(key) -1);
                        }
                    }
                    //if last case assigned was workers last case then increment the worker index.
                    if (workerIndex < this.selectedWorkers.size() && this.selectedWorkers[workerIndex].numCases.get(key) <= 0) {
                        workerIndex++;
                    }
                } else {
                    numAlreadyAssigned++;
                }
                huasByService.get(key).remove(0);
            }
        }
        update huasToUpdate;
        this.casesAssigned = true;
        fillUserList();
        this.setPageList();
        return null;
    }

    //function called for sorting list by certain fields
    public PageReference sortList(){
        if (this.currentSortColumn == this.sortColumn) {
            this.sortOrder = !this.sortOrder;
        } else {
            this.sortOrder = true;
        }
        this.currentSortColumn = this.sortColumn;
        this.currentStartNumber = 0;
        System.debug(Logginglevel.INFO,this.currentSortColumn);
        this.recordLBound = this.currentStartNumber + 1;
        this.setPageList();
        return null;
    }

    public PageReference searchService() {
        this.currentStartNumber = 0;
        this.recordLBound = this.currentStartNumber + 1;
        this.setPageList();
        return null;
    }
    // End Public Page Reference functions


    // Begin Public Helper Functions
    public List<selectOption> getPickValues(SObject object_name, String field_name, String first_val) {
        Framework.Log.push(HighUsageAlertController.class.getName(),'getPickValues');

        List<selectOption> options = new List<selectOption>(); //new list for holding all of the picklist options
        if (first_val != null) { //if there is a first value being provided
            options.add(new selectOption(first_val, first_val)); //add the first option
        }
        Schema.SObjectType sobject_type = object_name.getSObjectType(); //grab the sobject that was passed
        Schema.DescribeSObjectResult sobject_describe = sobject_type.getDescribe(); //describe the sobject

        //get a map of fields for the passed sobject
        Map<String, Schema.SObjectField> field_map = sobject_describe.fields.getMap();
        //grab the list of picklist values for the passed field on the sobject
        List<Schema.PicklistEntry> pick_list_values = field_map.get(field_name).getDescribe().getPickListValues();
        //for all values in the picklist list
        for (Schema.PicklistEntry a : pick_list_values) {
            //add the value and label to our final list
            options.add(new selectOption(a.getValue(), a.getLabel()));
        }

        Framework.Log.pop();
        //return the List
        return options;
    }

    public void selectAll() {
        for (HighUsageAlertWrapper huaWrapper :this.huaReportSetController) {
            huaWrapper.isSelected = this.selected;
        }
    }

    public Boolean hasNext {
        get {
            if (this.currentStartNumber + Integer.valueOf(this.displayAmount) >= this.totalCasesForPagination) {
                return false;
            } else {
                return true;
            }
        }
        set;
    }

    public Boolean hasPrevious {
        get {
            if (this.currentStartNumber < Integer.valueOf(this.displayAmount)) {
                return false;
            } else {
                return true;
            }
        }
        set;
    }

    public void next() {
        if (hasNext) {
            this.currentStartNumber += Integer.valueOf(this.displayAmount);
            this.recordLBound = this.currentStartNumber + 1;
            this.setPageList();
        }
    }

    public void previous() {
        if (hasPrevious) {
            this.currentStartNumber -= Integer.valueOf(this.displayAmount);
            this.recordLBound = this.currentStartNumber + 1;
            this.setPageList();
        }
    }

    public PageReference changeTableSize(){
        this.currentStartNumber = 0;
        this.recordLBound = this.currentStartNumber + 1;
        this.setPageList();
        return null;
    }
    //End Public Helper Functions

    // Begin Private Initiation Function
    private void buildServiceList() {
        //get list of service types from the picklist on the High Usage Alert object.
        //used in both user assignment and working the list so it is loaded here to save from loading on each refresh
        Schema.DescribeFieldResult fieldResult = HighUsageAlert__c.Service__c.getDescribe();
        List<Schema.PicklistEntry> serviceTypes = fieldResult.getPicklistValues();
        this.gridBuilderServiceList = new List<String>();
        this.caseServiceTotalAmounts = new Map<String, Integer>();
        for (Schema.PicklistEntry ple : serviceTypes) {
            this.gridBuilderServiceList.add('"' + ple.getLabel() + '"');
            this.caseServiceTotalAmounts.put(ple.getLabel(), 0);
            this.serviceSearchOptions.add(new SelectOption(ple.getLabel(), ple.getValue()));
        }
        //list used in javascript to loop over service types
        //this.gridBuilderServiceList= new List<String>(this.caseServiceTotalAmounts.keySet());
        this.workerCaseInitMap = this.caseServiceTotalAmounts.clone();
    }

    private Boolean casesToBeAssigned() {
        Integer unassignedCases =
                [SELECT COUNT()
                FROM HighUsageAlert__c
                WHERE OwnerId = :this.TOCAPIUSERID AND ActionCode__c = null];
        return unassignedCases > 0;
    }

    private void fillUserList() {
        this.userList = new List<SelectOption>();
        List<AggregateResult> tmp =
                [SELECT OwnerId, COUNT(Id)
                FROM HighUsageAlert__c
                WHERE OwnerId != :this.TOCAPIUSERID AND ActionCode__c = null
                GROUP BY OwnerId];

        List<Id> userIds = new List<Id>();
        for (AggregateResult ar : tmp) {
            userIds.add(String.valueOf(ar.get('OwnerID')));
        }
        List<User> workers =
        [SELECT Id, Name
        FROM User
        WHERE Id in :userIds];

        this.userList.add(new SelectOption('All', 'All'));
        for (User u :workers) {
            this.userList.add(new SelectOption(u.Id, u.Name));
        }
    }

    private void buildCaseTotals() {
        List<HighUsageAlert__c> huaList = getCaseList();

        for (HighUsageAlert__c hua :huaList) {
            Integer tmpCount = this.caseServiceTotalAmounts.get(hua.Service__c) + 1;
            this.caseServiceTotalAmounts.put(hua.Service__c, tmpCount);
        }
    }
    //End Private Initiation Functions

    // Begin Private Helper Functions
    private void setPageList(){
        //get list of cases that are open and are in the work queue for current user
        List<HighUsageAlertWrapper> huaFullList = getFullList();
        Boolean userInWorkerList = false;
        for (SelectOption so : this.userList) {
            if (so.getValue() != 'All' && so.getValue() == this.theUserId) {
                userInWorkerList = true;
            }
        }
        if (userInWorkerList) {
            huaFullList = getHUAUserList(huaFullList);
        }

        this.huaReportSetController = new List<HighUsageAlertWrapper>();

        if (this.serviceSearch != 'All' && this.serviceSearch != null) {
            huaFullList = getHUAListByService(huaFullList);
        }

        //find max index that we need to loop through subtract 1 becasue display amount is not zero based like arrays
        Integer maxIndex = this.currentStartNumber + Integer.valueOf(this.displayAmount) - 1;
        //If our new maxIndex is greater or equal to the case size then set maxIndex to the max index of the case list
        if (maxIndex >= huaFullList.size()) {
            maxIndex = huaFullList.size() - 1;
        }
        //fill the wrapper class
        for (Integer i = this.currentStartNumber; i <= maxIndex; i++) {
            this.huaReportSetController.add(huaFullList[i]);
        }

        this.totalCasesForPagination = huaFullList.size();
    }

    private List<HighUsageAlertWrapper> getFullList() {
        //get list of cases that are open and are in the leak queue for current user
        List<HighUsageAlert__c> huaList = getCaseList();
        List<HighUsageAlertWrapper> results = new List<HighUsageAlertWrapper>();

        //fill the wrapper class
        for (HighUsageAlert__c hua :huaList) {
            HighUsageAlertWrapper tmp = new HighUsageAlertWrapper();
            tmp.theCase = hua;
            if (hua.Case__r.Contact.Email == null) {
                tmp.actionCodes = this.actionCodeOptionsNoEmail;
            } else {
                tmp.actionCodes = this.actionCodeOptions;
            }
            results.add(tmp);
        }
        return results;
    }

    //get case list based on Status, Date, and Issue, List is already sorted on column and in the correct order
    private List<HighUsageAlert__c> getCaseList() {
        DateTime cutoffDate = Datetime.now().addDays(-7);
        String sortAorD = getSortOrderString();

        String highUsageOrder = '';
        if (this.currentSortColumn.split('\\.')[0] != 'Case__r') {
            highUsageOrder += this.currentSortColumn.split('\\.')[1]  + ' ' + sortAorD + ' NULLS LAST';
        } else {
            highUsageOrder += this.currentSortColumn + ' ' + sortAorD + ' NULLS LAST';
        }

        List<Case> tmpCases =
                [SELECT
                        (SELECT Id
                        FROM HighUsageAlerts__r
                        ORDER By CreatedDate DESC Limit 1)
                FROM Case
                WHERE (CaseIssue__c  = :this.HUACASEISSUEID OR CaseIssue__c = :this.RECLAIMEDISSUEID)
                    AND Status = :this.caseStatus AND LastModifiedDate >= :cutoffDate];

        List<Id> huaIDs = new List<Id>();
        for (Case c: tmpCases) {
            if (c.HighUsageAlerts__r != null && c.HighUsageAlerts__r.size() >= 1) {
                huaIDs.add(c.HighUsageAlerts__r[0].Id);
            }
        }
        /* Fields Pulled out due to not being in package yet
         * Account_Service__r.Id, Account_Service__r.CID__c,
         * Account_Service__r.LID__c, Account_Service__r.Service_Type__c,
         */
        String query =
                'SELECT Id, Name, OwnerID, CreatedDate, Case__c, Customer_Name__c, Meter_Number__c, Radio_Number__c, Service__c, '
                    + 'Class__c, Cycle_Route__c, Prior_7_Day_Average__c, Percent_Change__c, Prior_Day__c, Prior_2_Days__c, '
                    + 'Continous_Usuage__c, Contacted__c, CID__c, LID__c, Appearance_Count__c, Action_Code__c, Contact_Count__c, '
                    + 'No_Contact_Count__c, No_Contact_Workload__c,  Case__r.Id, Case__r.Priority, Case__r.Status, Case__r.CaseNumber, '
                    + 'Case__r.Description, Case__r.Contact.Email, Case__r.LastModifiedDate, Case__r.Account.Id, Case__r.Account.Name, '
                    + 'Case__r.Account.CID__c, Case__r.ServiceAddress__r.Id '
                + 'FROM HighUsageAlert__c '
                + 'WHERE Id in :huaIDs '
                + 'ORDER BY ' + highUsageOrder;

        System.debug(Logginglevel.INFO,query);
        return Database.query(query);
    }

    private String getSortOrderString() {
        if (this.sortOrder) {
            return 'DESC';
        } else {
            return 'ASC';
        }
    }

    private List<HighUsageAlertWrapper> getHUAUserList(List<HighUsageAlertWrapper> fullList) {
        List<HighUsageAlertWrapper> results = new List<HighUsageAlertWrapper>();
        for (HighUsageAlertWrapper huaw : fullList) {
            if (huaw.theCase.ownerID == this.theUserId) {
                results.add(huaw);
            }
        }
        return results;
    }

    private List<HighUsageAlertWrapper> getHUAListByService(List<HighUsageAlertWrapper> fullList) {
        List<HighUsageAlertWrapper> results = new List<HighUsageAlertWrapper>();
        for (HighUsageAlertWrapper huaw : fullList) {
            if (huaw.theCase.Service__c == this.serviceSearch) {
                results.add(huaw);
            }
        }
        return results;
    }

    private List<SelectOption> retrieveUtilityAccountsUserList() {
        //get list of all users in Utility Accounts who could work on high usage report and build a select option list.
        //hardcoded option is for testing, change to Utility Accounts Profile for live
        //List<User> tmpUser = [Select Id, Name From User Where ProfileID != :this.TOCAPIUSERID AND ProfileId != '00e36000000ahwc'];
        List<User> tmpUser =
                [SELECT Id, Name
                FROM User
                WHERE Id in
                        (SELECT AssigneeId
                        FROM PermissionSetAssignment
                        WHERE PermissionSetId = :this.HIGHUSAGEPERMISSION)];
        List<SelectOption> tmpSelectList = new List<SelectOption>();
        for (User u :tmpUser) {
            tmpSelectList.add(new SelectOption(u.Id, u.Name));
        }
        SelectOptionSorter.doSort(tmpSelectList, SelectOptionSorter.FieldToSort.Label);
        return tmpSelectList;
    }

    private void reassignCaseTotals() {
        String query = 'ActionCode__c = null';
        Framework.Selector huaList = new Framework.Selector(HighUsageAlert__c.getSObjectType(), query);

        for (HighUsageAlert__c hua : (List<HighUsageAlert__c>) huaList.getAll()) {
            Integer tmpCount = this.caseServiceTotalAmounts.get(hua.Service__c) + 1;
            this.caseServiceTotalAmounts.put(hua.Service__c, tmpCount);
        }
    }

    private void assignSameAccountHUAs(Map<String, List<HighUsageAlert__c>> sameAccounts) {
        List<String> keys = new List<String>(sameAccounts.keySet());
        List<HighUsageAlert__c> huasToUpdate = new List<HighUsageAlert__c>();
        for (Integer i = 0; i < keys.size(); i++) {
            List<HighUsageAlert__c> tmpHUAs = sameAccounts.get(keys[i]);
            Integer index = getHighestWorkload(tmpHUAs);
            if (index <= -1) {
                index = math.mod(i, this.selectedWorkers.size());
            }

            for (HighUsageAlert__c hua : tmpHUAs) {
                hua.OwnerID = this.selectedWorkers[index].userID;
                this.selectedWorkers[index].numCases.put(hua.Service__c, this.selectedWorkers[index].numCases.get(hua.Service__c) - 1);
            }
            huasToUpdate.addAll(tmpHUAs);
        }
        update huasToUpdate;
    }

    private Integer getHighestWorkload(List<HighUsageAlert__c> tmpHUAs) {
        Integer results = -1;
        Integer highestCases = 0;
        for (Integer i = 0; i < this.selectedWorkers.size(); i++) {
            Integer tmpHighestCases = this.selectedWorkers[i].getTotalCases();
            if (tmpHighestCases > highestCases && checkWorkLoad(this.selectedWorkers[i], tmpHUAs)) {
                results = i;
                highestCases = tmpHighestCases;
            }
        }
        return results;
    }

    private Boolean checkWorkLoad(HighUsageWorker huw, List<HighUsageAlert__c> tmpHUAs) {
        Map<String, Integer> caseCounts = new Map<String, Integer>();
        for (HighUsageAlert__c hua : tmpHUAs) {
            String tmpService = hua.Service__c;
            if (caseCounts.get(tmpService) == null) {
                caseCounts.put(tmpService, 1);
            } else {
                caseCounts.put(tmpService, caseCounts.get(tmpService) + 1);
            }
        }
        for (String key : caseCounts.keySet()) {
            if (huw.numCases.get(key) < caseCounts.get(key)) {
                return false;
            }
        }
        return true;
    }

    private Map<String, List<HighUsageAlert__c>> getSameAccounts() {
        List<AggregateResult> agrCaseIds =
        [SELECT Case__c, COUNT(Id)
        FROM HighUsageAlert__c
        WHERE ActionCode__c = null
        GROUP BY Case__c
        HAVING COUNT(Id) > 1];
        List<Id> caseIds = new List<Id>();
        for (AggregateResult ar :agrCaseIds) {
            caseIds.add(String.valueOf(ar.get('Case__c')));
        }

        List<Case> tmpCases =
        [SELECT Id,
        (SELECT Id, CreatedDate, ActionCode__c
        FROM HighUsageAlerts__r
        WHERE ActionCode__c = null
        ORDER BY CreatedDate DESC)
        FROM Case
        WHERE Id IN :caseIds];
        List<HighUsageAlert__c> huasToUpdate = new List<HighUsageAlert__c>();
        for (Case c : tmpCases) {
            List<HighUsageAlert__c> tmpHUAs = c.HighUsageAlerts__r;
            tmpHUAs.remove(0);
            for (HighUsageAlert__c hua : tmpHUAs) {
                hua.ActionCode__c = this.NEVERSEENAC.id;
            }
            huasToUpdate.addAll(tmpHUAs);
        }
        update huasToUpdate;

        Map<String, List<HighUsageAlert__c>> results = new Map<String, List<HighUsageAlert__c>>();
        List<HighUsageAlert__c> huaFullList =
        [SELECT Id, OwnerId, CID__c, Service__c
        FROM HighUsageAlert__c
        Where ActionCode__c = null];
        for (HighUsageAlert__c hua :huaFullList) {
            if (results.get(hua.CID__c) == null) {
                List<HighUsageAlert__c> tmp = new List<HighUsageAlert__c>();
                tmp.add(hua);
                results.put(hua.CID__c, tmp);
            } else {
                List<HighUsageAlert__c> tmp = results.get(hua.CID__c);
                tmp.add(hua);
                results.put(hua.CID__c, tmp);
            }
        }
        for (String cid :results.keySet()) {
            if (results.get(cid).size() <= 1) {
                results.remove(cid);
            }
        }
        return results;
    }

    private Map<String, List<HighUsageAlertWrapper>> divideHUAs() {
        Map<String, List<HighUsageAlertWrapper>> results = new Map<String, List<HighUsageAlertWrapper>>();
        for (HighUsageAlertWrapper huaWrapper :getFullList()) {
            String tmpService = huaWrapper.theCase.Service__c;
            if (results.get(tmpService) == null) {
                List<HighUsageAlertWrapper> tmp = new List<HighUsageAlertWrapper>();
                tmp.add(huaWrapper);
                results.put(tmpService, tmp);
            } else {
                results.get(tmpService).add(huaWrapper);
            }
        }
        return results;
    }
    // End Private Helper Functions

}