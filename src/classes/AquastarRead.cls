/*
 * Created by byarsawi on 1/28/2019.
 */
public with sharing class AquastarRead {

	public Double reading {get; set;}
	public Double delta {get; set;}
	public String readtime {get;set;}

	public AquastarRead(){
		this.reading = 0;
		this.delta = 0;
		this.readtime = null;
	}

	public AquastarRead(Double reading, Double delta, String readtime){
		this.reading = reading;
		this.delta = delta;
		this.readtime = readtime;
	}

}