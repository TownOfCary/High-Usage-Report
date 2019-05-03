/*
 * Created by byarsawi on 1/28/2019.
 */
@IsTest
private class Test_AquastarMeterReadController {

	static testMethod void testController() {
		PageReference pPageReference = Page.AquastarMeterRead;
		Test.startTest();

		Test.setMock(HttpCalloutMock.class, new AquastarAPIHTTPMock());

		System.currentPageReference().getParameters().put('meterNumber', '123456');
		AquastarMeterReadController amrCon = new AquastarMeterReadController();

		System.assertEquals(24, amrCon.aqua.reads.size());
		System.assertEquals('111111', amrCon.aqua.CID);

		amrCon.beginDate = Datetime.newInstanceGMT(Date.today().addDays(-1), Time.newInstance(0,0,0,0));
		amrCon.endDate = Datetime.newInstanceGMT(Date.today().addDays(-1), Time.newInstance(23,0,0,0));
		amrCon.updateDateRange();
		PageReference tmpPR = amrCon.exportToCSV();

		Test.stopTest();
	}

}