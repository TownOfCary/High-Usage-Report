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

    // Begin Initiation Private Function
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
                WHERE OwnerId != :this.TOCAPIUSERID AND Action_Code__c = null
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
    //End Initiation Private Functions
}