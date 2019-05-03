public with sharing class AquastarAccount {

	public String CID {get; set;}
	public String LID {get; set;}
	public String meterNumber {get; set;}
	public String service {get; set;}
	public Integer serviceSeq {get; set;}
	public List<AquastarRead> reads {get; set;}
	//change which line is commented for production
	//private final String AquastarAPIKey = 'AQUASTAR_PRODUCTION';
	private final String AquastarAPIKey = 'AQUASTAR_TEST';

	public AquastarAccount(){
		this.CID = '';
		this.LID = '';
		this.meterNumber = '';
		this.service = '';
		this.serviceSeq = 0;
		this.reads = new List<AquastarRead>();
	}

	public AquastarAccount(String meterNumber){
		//add a check for null here since we have already initialized all our strings as an empty string instead of null.
		if(meterNumber != null){
			this.meterNumber = meterNumber;
		} else {
			this.meterNumber = '';
		}

		this.CID = '';
		this.LID = '';
		this.service = '';
		this.serviceSeq = 0;
		this.reads = new List<AquastarRead>();
	}


	public Boolean getReads(Datetime beginTime, Datetime endTime){
		reads.clear();
		//if we have no meter number assigned to the account just return false
		if(meterNumber == ''){
			return false;
		}
		Datetime offsetBeginTime = beginTime.addSeconds(UserInfo.getTimeZone().getOffset(beginTime) / 1000);
		Datetime offsetEndTime = endTime.addSeconds(UserInfo.getTimeZone().getOffset(endTime) / 1000);
		system.debug(offsetBeginTime);
		system.debug(offsetEndTime);
		HttpRequest req = new HttpRequest();
		req.setEndPoint('callout:Aquastar_API/aquastarapi/meter_request/reads');
		req.setMethod('POST');
		req.setHeader('Content-Type', 'application/json');
		req.setHeader('Authorization', '{!$Credential.Password}');
		String body = generateJSONContent(offsetBeginTime, offsetEndTime);
		req.setBody(body);

		Http http = new Http();
		HTTPResponse res = http.send(req);
		if(res.getHeader('Content-Type').containsIgnoreCase('application/json')){
			system.debug(res.getBody());
			Map<String, Object> resBody = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
			if(Boolean.valueOf(resBody.get('success'))){
				List<Object> accounts = (List<Object>)resBody.get('accounts');
				Map<String, Object> acct = (Map<String, Object>)accounts[0];
				this.CID = String.valueOf(acct.get('cid'));
				this.LID = String.valueOf(acct.get('lid'));
				this.service = String.valueOf(acct.get('service'));
				this.serviceSeq = Integer.valueOf(acct.get('service_seq'));
				List<Object> meterReads = (List<Object>)acct.get('reads');
				Map<String, Object> tmp;
				for(Object o : meterReads){
					tmp = (Map<String, Object>)o;
					String readtime = String.valueOf(tmp.get('readtime'));
					system.debug(readtime);
					this.reads.add(new AquastarRead(
							Double.valueOf(tmp.get('multiplied_reading')),
							Double.valueOf(tmp.get('multiplied_delta')),
							readtime.replace('T', ' ')
					));
				}
				return true;
			}
		}
		return false;
	}

	private String generateJSONContent(Datetime beginTime, Datetime endTime) {
		// Create a JSONGenerator object.
		// Pass true to the constructor for pretty print formatting.
		JSONGenerator gen = JSON.createGenerator(true);

		// Write data to the JSON string.
		gen.writeStartObject();
		gen.writeFieldName('meter_request');
		gen.writeStartObject();
		gen.writeStringField('user', UserInfo.getUserName());
		gen.writeFieldName('accounts');
		gen.writeStartArray();
		gen.writeStartObject();
		gen.writeStringField('meter_number', meterNumber);
		gen.writeDateTimeField('begin_date', beginTime);
		gen.writeDateTimeField('end_date', endTime);
		gen.writeEndObject();
		gen.writeEndArray();
		gen.writeEndObject();
		gen.writeEndObject();

		// Return the JSON string.
		return gen.getAsString();
	}
}