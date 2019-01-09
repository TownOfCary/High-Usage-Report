/*
 * Created by byarsawi on 1/9/2019.
 */
@IsTest
private class Test_HighUsageAlertService {

	static Boolean isInstalled = false;

	private static void install() {
		if (!isInstalled) {
			Framework.Installer.install();
			base_toc.PackageScripts.install();
			pwut_toc.PackageScripts.install();
			PackageScripts.install();
			isInstalled = true;
		}
	}

	@TestSetup
	static void setup() {
		Test_HighUsageDataFactory.testPrep(5, 5, 5);
	}

	@IsTest
	static void huaInsertCreatesNewCase(){
		install();
		Test.startTest();
		
		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		Test.stopTest();
		
		High_Usage_Alert__c newHUA = 
				[SELECT Id, Case__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];
		System.assert(newHUA.Case__c != null);
	}

	@IsTest
	static void accountServiceIsAttachedToHUAOnInsert() {
		install();
		Test.startTest();
		
		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		Test.stopTest();

		High_Usage_Alert__c newHUA = 
				[SELECT Id, Account_Service__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];

		System.assert(newHUA.Account_Service__c != NULL);
	}

	@IsTest
	static void ifCaseAlreadyExitstsForHUAAttachHUAToCase() {
		install();
		Test.startTest();

		List<High_Usage_Alert__c>  huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		High_Usage_Alert__c firstHUA =
				[SELECT Id, Case__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];

		huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		Test.stopTest();

		High_Usage_Alert__c secondHUA =
				[SELECT Id, Case__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];

		System.assert(firstHUA.Case__c != null);
		System.assertEquals(firstHUA.Case__c, secondHUA.Case__c);
	}

	@IsTest
	static void testAccountsWithDifferentMetersOnSameServiceAreNotEqual() {
		install();
		Test.startTest();

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(2, 0, 1, true);

		Test.stopTest();

		List<High_Usage_Alert__c> oddManOut =
				[SELECT Id, Case__c
				FROM High_Usage_Alert__c
				WHERE Service__c = 'RW'];
		System.assert(oddManOut.size() > 0);

		List<High_Usage_Alert__c> sameHUAs =
				[SELECT Id, Case__c, CID__c
				FROM High_Usage_Alert__c
				WHERE Service__c = 'WA'];

		System.assertNotEquals(sameHUAs[0].Case__c, sameHUAs[1].Case__c);
		System.assertNotEquals(oddManOut[0].Case__c, sameHUAs[0].Case__c);
	}

	@IsTest
	static void testSameClientButDifferentAccountService() {
		install();
		Test.startTest();

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 1, 0, false);

		Test.stopTest();

		List<High_Usage_Alert__c> allHUAs =
				[SELECT Id, Case__c, CID__c
				FROM High_Usage_Alert__c];

		System.assertNotEquals(allHUAs[0].Case__c, allHUAs[1].Case__c);
	}

	@IsTest
	static void testHUACountsUpdateOnInsert() {
		install();
		Test.startTest();

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 1, 1, false);

		List<High_Usage_Alert__c> newHUAs =
				[SELECT Id, Case__c, Action_Code__c, Meter_Number__c, Appearance_Count__c, Contact_Count__c, No_Contact_Workload__c
				FROM High_Usage_Alert__c
				WHERE Service__c = 'WA'
				ORDER BY Name];

		System.assertEquals(1, newHUAs[0].Appearance_Count__c);

		huaList = Test_HighUsageDataFactory.createHUAs(1, 1, 1, false);
		newHUAs =
				[SELECT Id, Case__c, CID__c, LID__c, Action_Code__c, Meter_Number__c, Appearance_Count__c, Contact_Count__c, No_Contact_Workload__c
				FROM High_Usage_Alert__c
				WHERE Service__c = 'WA'
				ORDER BY Name DESC];
		//Second Insert should have two appearances for HUA on 'WA' service and 1 No Contact Workload
		//because there was no action code give for then previous HUA.
		System.assertEquals(2, newHUAs[0].Appearance_Count__c);
		System.assertEquals(0, newHUAs[0].Contact_Count__c);
		System.assertEquals(1, newHUAs[0].No_Contact_Workload__c);

		huaList = new List<High_Usage_Alert__c>();
		huaList.add(new High_Usage_Alert__c(
				Customer_Name__c = 'TestAcct',
				Service__c = 'WA',
				CID__c = newHUAs[0].CID__c,
				LID__c = newHUAs[0].LID__c,
				Meter_Number__c = newHUAs[0].Meter_Number__c,
				Class__c = 'C',
				Continuous_Usage__c = 24,
				Hourly_Usage__c = 24,
				Appearance_Count__c = 4
		));

		insert huaList;

		Test.stopTest();

		newHUAs =
				[SELECT Id, Name, Case__c, Action_Code__c, Appearance_Count__c, Contact_Count__c, No_Contact_Count__c, No_Contact_Workload__c, CreatedDate
				FROM High_Usage_Alert__c
				WHERE Service__c = 'WA'
				ORDER BY Name Desc];
		//Last insert has an appearance count FROM the SAS report which should be ignored.  The Count should be 3 after this insert.
		System.assertEquals(3, newHUAs[0].Appearance_Count__c);
		System.assertEquals(0, newHUAs[0].Contact_Count__c);
		System.assertEquals(2, newHUAs[0].No_Contact_Workload__c);
		System.assertEquals(0, newHUAs[0].No_Contact_Count__c);
	}

	//Test Has had the email check not included until we actually start using the email
	@IsTest
	static void actionCodeNoContactWorkloadClosesCaseAndSendsEmail() {
		install();

		List<Action_Code__c> actionCodeList =
				[SELECT Id, Name
				FROM Action_Code__c
				WHERE Name = 'No Contact-Workload'];

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);
		High_Usage_Alert__c newHUA =
				[SELECT Id, Account_Service__c, Case__c, Action_Code__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];

		Case c =
				[SELECT Id, ContactId
				FROM Case
				WHERE Id = :newHUA.Case__c];
		//create contact for sending the email
		Contact con = new Contact(
				LastName = 'Doe',
				Email = 'test@test.org'
		);
		insert con;
		c.ContactId = con.Id;
		update c;

		Test.startTest();

		newHUA.Action_Code__c = actionCodeList[0].Id;
		update newHUA;

		Test.stopTest();

		Case result =
			[SELECT Id, Status
			FROM Case
			WHERE Id = :c.Id];
		System.assertEquals('On Hold', result.Status);
		//System.assert(newHUA.Contacted__c);
	}

	@IsTest
	static void actionCodeDispatchedPWUTWillHaveWorkOrderCreatedOnHUA() {
		install();
		List<WorkType> wt = new List<WorkType>();
		wt.add(new WorkType(
				Name = 'Work Order Work Type',
				ShouldAutoCreateSvcAppt = true,
				EstimatedDuration = 1,
				DurationType = 'Hours',
				pwut_toc__Price_Book__c = Test.getStandardPricebookId(),
				pwut_toc__Inactive__c = false
		));
		insert wt;
		List<Account> acct = new List<Account>();
		acct.add(new Account(
				Name = 'Meter Account'
		));
		insert acct;
		List<Asset> assets = new List<Asset>();
		assets.add(new Asset(
				AccountId = acct[0].Id,
				Name = 'Meter Asset'
		));
		insert assets;

		List<Action_Code__c> actionCodeList = new List<Action_Code__c>();
		actionCodeList.add(new Action_Code__c(
				Name = 'Dispatched PWUT',
				Case_Status__c = 'In Progress',
				Work_Order__c = true,
				Work_Type__c = wt[0].Id
		));
		insert actionCodeList;

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		High_Usage_Alert__c newHUA =
				[SELECT Id, Case__c, Action_Code__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];
		Case c =
				[SELECT Id,
				AssetId FROM
				Case WHERE Id = :newHUA.Case__c];
		c.AssetId = assets[0].Id;
		update c;

		newHUA.Action_Code__c = actionCodeList[0].Id;

		Test.startTest();

		update newHUA;

		Test.stopTest();

		c =
				[SELECT Id, Status, AssetId,
						(SELECT Id, AssetId
						FROM WorkOrders)
				FROM Case
				WHERE Id = :newHUA.Case__c];

		System.assertEquals(1, c.WorkOrders.size());
		System.assertEquals(assets[0].Id, c.WorkOrders[0].AssetId);
	}

	@IsTest
	static void actionCodeNoContactDecisionClosesCase() {
		install();
		List<Action_Code__c> actionCodeList = new List<Action_Code__c>();
		actionCodeList.add(new Action_Code__c(
				Name = 'Close Case',
				Case_Status__c = 'Closed'
		));
		insert actionCodeList;

		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1, 0, 0, false);

		High_Usage_Alert__c newHUA =
				[SELECT Id, Case__c, Action_Code__c
				FROM High_Usage_Alert__c
				WHERE Id = :huaList[0].Id];
		newHUA.Action_Code__c = actionCodeList[0].Id;

		Test.startTest();

		update newHUA;

		Test.stopTest();

		Case c =
				[SELECT Id, Status
				FROM Case
				WHERE Id = :newHUA.Case__c];

		System.assertEquals('Closed', c.Status);
	}

}