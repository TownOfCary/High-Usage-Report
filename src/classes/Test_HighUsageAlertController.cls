/**
 * Created by byarsawi on 5/14/2018.
 */

@IsTest
private class Test_HighUsageAlertController {

    static Boolean isInstalled = false;
    static Group g;
    static Profile p;
    static User u;

    private static void install() {
        if (!isInstalled) {
            Framework.Installer.install();
            base_toc.PackageScripts.install();
            pwut_toc.PackageScripts.install();
            PackageScripts.install();
			initUser('HighUsageControllerTest@test.com');
			initUser('HighUsageControllerTest2@test.com');
			initUser('HighUsageControllerTest3@test.com');
            isInstalled = true;
        }
    }

    static void initUser(String userName) {
        User thisUser =
                [SELECT Id
                FROM User
                WHERE Id = :UserInfo.getUserId()];
        system.runAs(thisuser) {
            p =
                    [SELECT Id
                    FROM Profile
                    WHERE Name ='System Administrator'];
            u = new User(
                    Alias = 'testUser',
                    LastName = 'Testing',
                    UserName = userName,
                    ProfileId = p.Id,
                    Email = username,
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    TimeZoneSidKey = 'America/New_York'
            );

            insert u;

            PermissionSet per =
                    [SELECT Id
                    FROM PermissionSet
                    WHERE Name = 'High_Usage_Report'];
            PermissionSetAssignment psa = new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetId = per.Id
            );
            insert psa;
        }
    }

	@TestSetup
	static void setup() {
		Test_HighUsageDataFactory.testPrep(15, 5, 5);
	}

    @IsTest
    static void selectAllSelectsAllVisibleRecords() {
        install();
        List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(5,0,0, false);

        Test.startTest();

        HighUsageAlertController highUsageController = new HighUsageAlertController();
        highUsageController.selected = true;
        highUsageController.selectAll();
        for (HighUsageAlertWrapper huaWrapper : highUsageController.huaReportSetController) {
            System.Assert(huaWrapper.isSelected);
        }
        highUsageController.selected = false;
        highUsageController.selectAll();
        for (HighUsageAlertWrapper huaWrapper : highUsageController.huaReportSetController) {
            System.Assert(!huaWrapper.isSelected);
        }

        Test.stopTest();
    }

    @IsTest
    static void closeRemaingSetsActionCodeAndClosesCase() {
        install();
        List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(2, 2, 0, false);
        Action_Code__c actionCode =
                [SELECT Id
                FROM Action_Code__c
                WHERE Name = 'No Contact-Workload'];

        Test.startTest();

        HighUsageAlertController highUsageController = new HighUsageAlertController();
        highUsageController.closeRemaining();

        Test.stopTest();

        for(HighUsageAlertWrapper huaWrapper : highUsageController.huaReportSetController) {
            Case c =
                    [SELECT Id, Status
                    FROM Case
                    WHERE Id = :huaWrapper.theCase.Case__c];
            System.assertEquals('On Hold', c.Status);
            System.assertEquals(actionCode.Id, huaWrapper.theCase.Action_Code__c);
        }
    }

    @IsTest
    static void saveInlineChangesSavesChanges() {
        install();
        //LIST NEEDS TO BE ASSIGNED IN ORDER TO HAVE A SET LIST
        List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(1,0,1,false);
        PageReference pageRef = new PageReference('/apex/HighUsageAlertReport');
        Test.setCurrentPage(pageRef);
        Test.startTest();

        System.runAs(u) {
            List<String> workerIds = new List<String>();
            workerIds.add(u.id);

            String testString = 'Testing Save';
            HighUsageAlertController highUsageController = new HighUsageAlertController();
            highUsageController.workersToAdd = workerIds;
            highUsageController.doSelect();

            highUsageController.selectedWorkers[0].numCases.put('WA', 1);
            highUsageController.selectedWorkers[0].numCases.put('RW', 1);
            highUsageController.saveWorkerInfo();

            highUsageController.huaReportSetController[0].theCase.Case__r.Description = testString;
            PageReference nextPage = highUsageController.saveInlineChanges();

            //withoutsetting isSelected to true on the wrapper class nothing should be saved.
            System.assertNotEquals(testString, highUsageController.huaReportSetController[0].theCase.Case__r.Description);

            //test that saves happen
            highUsageController.huaReportSetController[0].theCase.Case__r.Description = testString;
            highUsageController.huaReportSetController[0].isSelected = true;
            nextPage = highUsageController.saveInlineChanges();

            System.assertEquals(testString, highUsageController.huaReportSetController[0].theCase.Case__r.Description);
        }

        Test.stopTest();
    }

	@IsTest
	static void assignWorkersDividesCaseListEvenly() {

		install();
		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(4,0,0, false);

		u =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest@test.com'];
		User u2 =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest2@test.com'];
		User u3 =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest3@test.com'];
		List<String> workerIds = new List<String>();
		workerIds.add(u.id);
		workerIds.add(u2.id);
		workerIds.add(u3.id);
		Test.startTest();

		User thisUser =
				[SELECT Id
				FROM User
				WHERE Id = :UserInfo.getUserId()];
		System.runAs(u2) {
			HighUsageAlertController highUsageController = new HighUsageAlertController();
			highUsageController.workersToAdd = workerIds;
			highUsageController.doSelect();
			system.assertEquals(3,highUsageController.selectedWorkers.size());

			highUsageController.selectedWorkers[2].isSelected = true;
			highUsageController.doUnSelect();
			system.assertEquals(2,highUsageController.selectedWorkers.size());

			highUsageController.selectedWorkers[0].numCases.put('WA', 2);
			highUsageController.selectedWorkers[1].numCases.put('WA', 2);
			highUsageController.saveWorkerInfo();

			system.assertEquals(2, highUsageController.huaReportSetController.size());

			System.runAs(thisUser) {
				Case tmpC =
						[SELECT Id, Status
						FROM Case
						WHERE Id = :highUsageController.huaReportSetController[0].theCase.Case__c];
				tmpC.Status = 'Reoccurring';
				update tmpC;
			}

			highUsageController.caseStatus = 'Reoccurring';
			highUsageController.changeCaseList();

			List<Case> c =
					[SELECT Id
					FROM Case];
			system.assertEquals(4,c.size());
			system.assertEquals(1, highUsageController.totalCasesForPagination);
			system.assertEquals(1, highUsageController.huaReportSetController.size());
			List<SelectOption> tmp = highUsageController.getRowAmount();
			highUsageController.displayAmount = '25';
			highUsageController.changeTableSize();

		}

		Test.stopTest();
	}

	@IsTest
	static void assignWorkersKeepsCasesWithSameAccounts(){

		install();
		List<High_Usage_Alert__c> sameAccountHUA = Test_HighUsageDataFactory.createHUAs(2, 2, 2, true);
		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(2, 2, 2, false);
		System.debug(Logginglevel.INFO,
				[SELECT Id, Customer_Name__c, CID__c, OwnerID, Case__c, Service__c
				FROM High_Usage_Alert__c]);
		u =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest@test.com'];
		User u2 =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest2@test.com'];
		List<String> workerIds = new List<String>();
		workerIds.add(u.id);
		workerIds.add(u2.id);

		Test.startTest();

		System.runAs(u2) {
			HighUsageAlertController highUsageController = new HighUsageAlertController();
			highUsageController.workersToAdd = workerIds;
			highUsageController.doSelect();

			highUsageController.selectedWorkers[0].numCases.put('WA', 2);
			highUsageController.selectedWorkers[0].numCases.put('IR', 2);
			highUsageController.selectedWorkers[0].numCases.put('RW', 2);
			highUsageController.selectedWorkers[1].numCases.put('WA', 2);
			highUsageController.selectedWorkers[1].numCases.put('IR', 2);
			highUsageController.selectedWorkers[1].numCases.put('RW', 2);
			highUsageController.saveWorkerInfo();

			system.assertEquals(6, highUsageController.huaReportSetController.size());
			String theCID = highUsageController.huaReportSetController[0].theCase.CID__c;
			system.assert(theCID == highUsageController.huaReportSetController[1].theCase.CID__c
					&& theCID == highUsageController.huaReportSetController[2].theCase.CID__c
					&& theCID == highUsageController.huaReportSetController[3].theCase.CID__c
					&& theCID == highUsageController.huaReportSetController[4].theCase.CID__c
					&& theCID == highUsageController.huaReportSetController[5].theCase.CID__c);

		}

		Test.stopTest();
	}

	@IsTest
	static void testSort(){
		install();
		List<High_Usage_Alert__c>  huaList = Test_HighUsageDataFactory.createHUAs(4, 0, 0, false);
		u =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest@test.com'];
		List<String> workerIds = new List<String>();
		workerIds.add(u.id);

		Test.startTest();

		HighUsageWorker hw = new HighUsageWorker();
		System.runAs(u) {
			HighUsageAlertController highUsageController = new HighUsageAlertController();
			highUsageController.workersToAdd = workerIds;
			highUsageController.doSelect();
			highUsageController.selectedWorkers[0].numCases.put('WA', 4);
			highUsageController.saveWorkerInfo();

			highUsageController.sortColumn = 'Case__r.CaseNumber';
			highUsageController.sortList();
			highUsageController.sortColumn = 'High_Usage_Alert__c.Customer_Name__c';
			highUsageController.sortList();
			System.assertEquals('25', highUsageController.displayAmount);
			List<SelectOption> tmp = highUsageController.caseStatusList;
		}

		Test.stopTest();
	}

	@IsTest
	static void testItterable() {
		install();
		List<High_Usage_Alert__c> huaList = Test_HighUsageDataFactory.createHUAs(15, 0, 0, false);
		system.debug('hua lsit size');
		system.debug(huaList.size());
		u =
				[SELECT Id
				FROM User
				WHERE UserName = 'HighUsageControllerTest@test.com'];
		List<String> workerIds = new List<String>();
		workerIds.add(u.id);

		Test.startTest();

		HighUsageWorker hw = new HighUsageWorker();
		System.runAs(u) {
			HighUsageAlertController highUsageController = new HighUsageAlertController();
			highUsageController.workersToAdd = workerIds;
			highUsageController.doSelect();
			highUsageController.selectedWorkers[0].numCases.put('WA', 15);
			highUsageController.saveWorkerInfo();
			highUsageController.displayAmount = '10';
			highUsageController.changeTableSize();
			highUsageController.next();
			system.assertEquals(5, highUsageController.huaReportSetController.size());
			system.assertEquals(15, highUsageController.recordUBound);
			highUsageController.previous();
			system.assertEquals(10, highUsageController.huaReportSetController.size());
			system.assertEquals(10, highUsageController.recordUBound);
		}

		Test.stopTest();
	}

}