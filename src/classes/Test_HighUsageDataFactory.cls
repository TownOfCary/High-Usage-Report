/*
 * Created by byarsawi on 1/9/2019.
 */
@IsTest
public class Test_HighUsageDataFactory {

	public static void testPrep(Integer numHUAWA, Integer numHUAIR, Integer numHUARW){
		List<Account> accts = new List<Account>();
		List<base_toc__Account_Service__c> accountServiceList = new List<base_toc__Account_Service__c>();
		List<base_toc__Service_Address__c> serviceAddressList = new List<base_toc__Service_Address__c>();
		List<base_toc__Service_Location__c> serviceLocationList = new List<base_toc__Service_Location__c>();

		//static ammounts created
		List<Action_Code__c>actionCodeList = new List<Action_Code__c>();

		for(Integer i = 1; i <= numHUAWA; i++) {
			accts.add(new Account(
					Name = 'TestAccount' + i,
					base_toc__CID__c = String.valueOf(i * 100)
			));
			serviceAddressList.add(new base_toc__Service_Address__c(
					base_toc__LID__c = String.valueOf(i * 200),
					base_toc__Street_Address__c = String.valueOf(i * 200) + ' Main St',
					base_toc__City__c = 'Cary',
					base_toc__Zip__c = String.valueOf(Math.roundToLong(Math.floor(Math.random() * 90000 + 10000)))
			));
		}

		for(Integer i = 1; i <= numHUAIR; i++) {
			accts.add(new Account(
					Name = 'TestAccount' + i,
					base_toc__CID__c = String.valueOf(i * 1000)
			));
			serviceAddressList.add(new base_toc__Service_Address__c(
					base_toc__LID__c = String.valueOf(i * 2000),
					base_toc__Street_Address__c = String.valueOf(i * 200) + ' Main St',
					base_toc__City__c = 'Cary',
					base_toc__Zip__c = String.valueOf(Math.roundToLong(Math.floor(Math.random() * 90000 + 10000)))
			));
		}

		for(Integer i = 1; i <= numHUARW; i++) {
			accts.add(new Account(
					Name = 'TestAccount' + i,
					base_toc__CID__c = String.valueOf(i * 10000)
			));
			serviceAddressList.add(new base_toc__Service_Address__c(
					base_toc__LID__c = String.valueOf(i * 20000),
					base_toc__Street_Address__c = String.valueOf(i * 200) + ' Main St',
					base_toc__City__c = 'Cary',
					base_toc__Zip__c = String.valueOf(Math.roundToLong(Math.floor(Math.random() * 90000 + 10000)))
			));
		}


		accts.add(new Account(
				Name = 'TestSameAccount',
				base_toc__CID__c = '100000'
		));
		serviceAddressList.add(new base_toc__Service_Address__c(
				base_toc__LID__c = '200000',
				base_toc__Street_Address__c = '200 Main St',
				base_toc__City__c = 'Cary',
				base_toc__Zip__c = String.valueOf(Math.roundToLong(Math.floor(Math.random() * 90000 + 10000)))
		));

		actionCodeList.add(new Action_Code__c(
				Name = 'Dispatched PWUT',
				Case_Status__c = 'Work Created',
				Work_Order__c = true
		));

		actionCodeList.add(new Action_Code__c(
				Name = 'No Contact-Decision',
				Case_Status__c = 'Closed',
				Work_Order__c = false
		));


		insert actionCodeList;
		insert accts;
		insert serviceAddressList;

		accts =
				[SELECT Id, Name, base_toc__CID__c
				FROM Account
				WHERE base_toc__CID__c != NULL
				ORDER BY base_toc__CID__c];
		serviceAddressList =
				[SELECT Id, base_toc__LID__c
				FROM base_toc__Service_Address__c
				ORDER BY base_toc__LID__c];

		for(Integer i = 0; i < numHUAWA + numHUAIR + numHUARW; i++) {
			serviceLocationList.add(new base_toc__Service_Location__c(
					base_toc__Account__c = accts[i].Id,
					base_toc__Service_Address__c = serviceAddressList[i].Id
			));
		}

		serviceLocationList.add(new base_toc__Service_Location__c(
				base_toc__Account__c = accts[accts.size() - 1].Id,
				base_toc__Service_Address__c = serviceAddressList[serviceAddressList.size() - 1].Id
		));

		insert serviceLocationList;

		for(base_toc__Service_Location__c sl :serviceLocationList) {
			accountServiceList.add(new base_toc__Account_Service__c(
					base_toc__Service_Type__c = 'WA',
					base_toc__Service_Location__c = sl.Id

			));
			accountServiceList.add(new base_toc__Account_Service__c(
					base_toc__Service_Type__c = 'IR',
					base_toc__Service_Location__c = sl.Id
			));
			accountServiceList.add(new base_toc__Account_Service__c(
					base_toc__Service_Type__c = 'RW',
					base_toc__Service_Location__c = sl.Id
			));
		}

		insert accountServiceList;
	}

	public static List<High_Usage_Alert__C> createHUAs(Integer numHUAWA, Integer numHUAIR, Integer numHUARW, Boolean sameAccount) {
		//User used for inserts on all new cases.  Making sure code that checks for this user works in tests.
		List<High_Usage_Alert__C> huaList = new List<High_Usage_Alert__C>();
		List<Account> acctList =
				[SELECT Id, Name, base_toc__CID__c
				FROM Account
				ORDER BY base_toc__CID__c];
		for(Integer i = 1; i <= numHUAWA; i++){
			huaList.add(new High_Usage_Alert__C(
					Customer_Name__c = acctList[math.mod(i - 1, acctList.size())].Name,
					Service__c = 'WA',
					CID__c = sameAccount ? '100000' : String.valueOf(i * 100),
					LID__c = String.valueOf(i * 200),
					Meter_Number__c = String.valueOf(i * 300),
					Radio_Number__c = String.valueOf(i * 400),
					Class__c = 'C',
					Continuous_Usage__c = 24,
					Hourly_Usage__c = 24
			));
		}
		for(Integer i = 1; i <= numHUAIR; i++){
			huaList.add(new High_Usage_Alert__C(
					Customer_Name__c = acctList[math.mod(i - 1, acctList.size())].Name,
					Service__c = 'IR',
					CID__c = sameAccount ? '100000' : String.valueOf(i * 1000),
					LID__c = String.valueOf(i * 200),
					Meter_Number__c = String.valueOf(i * 301),
					Radio_Number__c = String.valueOf(i * 400),
					Class__c = 'C',
					Continuous_Usage__c = 24,
					Hourly_Usage__c = 24
			));
		}
		for(Integer i = 1; i <= numHUARW; i++){
			huaList.add(new High_Usage_Alert__C(
					Customer_Name__c = acctList[math.mod(i - 1, acctList.size())].Name,
					Service__c = 'RW',
					CID__c = sameAccount ? '100000' : String.valueOf(i * 10000),
					LID__c = String.valueOf(i * 200),
					Meter_Number__c = String.valueOf(i * 302),
					Radio_Number__c = String.valueOf(i * 400),
					Class__c = 'C',
					Continuous_Usage__c = 24,
					Hourly_Usage__c = 24
			));
		}
		system.debug(huaList);
		insert huaList;
		return huaList;
	}

}