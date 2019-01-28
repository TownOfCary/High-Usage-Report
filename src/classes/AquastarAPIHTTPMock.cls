@IsTest
global class AquastarAPIHTTPMock implements HttpCalloutMock {

	global HTTPResponse respond(HTTPRequest req) {
		// Create a fake response.
		HttpResponse res = new HttpResponse();
		res.setHeader('Content-Type', 'application/json');
		res.setStatusCode(200);

		JSONGenerator gen = JSON.createGenerator(true);

		gen.writeStartObject();
		gen.writeBooleanField('success', true);
		gen.writeFieldName('accounts');
		gen.writeStartArray();
		gen.writeStartObject();
		gen.writeStringField('cid', '111111');
		gen.writeStringField('meter_number', '123456');
		gen.writeStringField('lid', '654321');
		gen.writeStringField('service', 'WA');
		gen.writeStringField('service_seq', '0');
		gen.writeFieldName('reads');
		gen.writeStartArray();
		for (Integer i = 0; i < 24; i++) {
			gen.writeStartObject();
			gen.writeDateTimeField('readtime', Datetime.newInstanceGMT(Date.today().addDays(-1), Time.newInstance(i,0,0,0)));
			gen.writeStringField('multiplied_reading', String.valueOf(i * 100));
			gen.writeStringField('multiplied_delta', '0');
			gen.writeEndObject();
		}
		gen.writeEndArray();
		gen.writeEndObject();
		gen.writeEndArray();
		gen.writeEndObject();
		res.setBody(gen.getAsString());
		return res;
	}

}