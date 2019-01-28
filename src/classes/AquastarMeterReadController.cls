/*
 * Created by byarsawi on 1/28/2019.
 */
public with sharing class AquastarMeterReadController {

	public AquastarAccount aqua { get; set; }
	public Datetime beginDate { get; set; }
	public Datetime endDate{ get; set; }
	public String meterNumber{ get; set; }
	public String csvFileName { get; set; }

	private ApexPages.Message resultsError;

	public AquastarMeterReadController() {
		//set custom results error to use in no results returned from AquastarAccount.getReads()
		//resultsError = ;
		//get passed in meter number value from the querystring
		meterNumber = ApexPages.currentPage().getParameters().get('meterNumber');
		//use meter number and default date time period to get reads from aquastar
		aqua = new AquastarAccount(meterNumber);
		beginDate = DateTime.newInstance(Date.today().addDays(-3), Time.newInstance(0,0,0,0));
		endDate = DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(23,59,59,997));

		if (!aqua.getReads(beginDate, endDate)) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to get results at this time.  Please check meter number and date range or contact admin to check status of the Aquastar API'));
		}
		csvFileName = aqua.LID + Datetime.now().format('YYYY-MM-dd_HH-mm-ss') + '.csv';
	}

	public PageReference updateDateRange() {
		if(!aqua.getReads(beginDate, endDate)){
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unable to get results at this time.  Please check meter number and date range or contact admin to check status of the Aquastar API'));
		}
		return null;
	}

	public PageReference exportToCSV() {
		PageReference pageRef= new PageReference('/apex/AquastarCSVExport');
		pageRef.setRedirect(false);
		return pageRef;
	}

}