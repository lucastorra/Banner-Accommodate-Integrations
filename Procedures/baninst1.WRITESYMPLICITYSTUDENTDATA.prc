CREATE OR REPLACE PROCEDURE BANINST1.writeSymplicityStudentData(loadType in varchar2) is
    
/******************************************************************************
   NAME:       writeSymplicityStudentData
   PURPOSE:    Symplicity Accommodate Student XML File Creation
               This procedure writes the student data feed text file with data from the SZBSYMS table.
 
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
   
   1.1        21-FEB-2023 Nigel Tourney    	RFC 561753 - Add external email address 
											to Student file
											
   1.2		  09-MAY-2023 Nigel Tourney		RFC 561854 - Changed full file to only pull changes since 01-JUL-2022
											
******************************************************************************/
	
    fHand   UTL_FILE.file_type;
    fName   varchar2(50);


BEGIN
    --Full load type is generated once per week (Sunday night).
    if loadType = 'F' then
        --Create and open full student data text file.
        fName := 'studentDataFull_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);

        --Generate column headers.        
        utl_file.put(fHand, 'USERNAME|STUDENTID|FIRSTNAME|LASTNAME|FULLNAME|');
        utl_file.put(fHand, 'MIDDLENAME|PREFNAME|EMAIL|PHONE|BIRTHDATE|');	
        utl_file.put(fHand, 'GENDER|PRONOUN|ETHNICITY|CITIZENSHIP|PERMSTREETLINE1|');
        utl_file.put(fHand, 'PERMSTREETLINE2|PERMSTREETLINE3|PERMCITY|PERMPROV|');
        utl_file.put(fHand, 'PERMPOSTCODE|PERMCOUNTRY|CURRSTREETLINE1|CURRSTREETLINE2|');
        utl_file.put(fHand, 'CURRSTREETLINE3|CURRCITY|CURRPROV|CURRPOSTCODE|CURRCOUNTRY|');
        utl_file.put(fHand, 'DISABILITY|EMRCONTFNAME|EMRCONTLNAME|EMRCONTRELTN|');
        utl_file.put(fHand, 'EMRCONTPHONE|RECTYPE|APPTERM1|APPNUM1|APPLVLCODE1|');
        utl_file.put(fHand, 'APPSTYPCODE1|APPRESD1|APPFPTIME1|APPDECISION1|APPDECDATE1|APPCAMPUS1|');
        utl_file.put(fHand, 'APPCOLLCODE1|APPDEGCODE1|APPMAJCODE1|APPPGMCODE1|');
        utl_file.put(fHand, 'APPTERM2|APPNUM2|APPLVLCODE2|APPSTYPCODE2|APPRESD2|');
        utl_file.put(fHand, 'APPFPTIME2|APPDECISION2|APPDECDATE2|APPCAMPUS2|APPCOLLCODE2|');
        utl_file.put(fHand, 'APPDEGCODE2|APPMAJCODE2|APPPGMCODE2|APPTERM3|APPNUM3|');
        utl_file.put(fHand,	'APPLVLCODE3|APPSTYPCODE3|APPRESD3|APPFPTIME3|APPDECISION3|');
        utl_file.put(fHand,	'APPDECDATE3|APPCAMPUS3|APPCOLLCODE3|APPDEGCODE3|APPMAJCODE3|');
        utl_file.put(fHand,	'APPPGMCODE3|APPTERM4|APPNUM4|APPLVLCODE4|APPSTYPCODE4|');
        utl_file.put(fHand,	'APPRESD4|APPFPTIME4|APPDECISION4|APPDECDATE4|APPCAMPUS4|');
        utl_file.put(fHand,	'APPCOLLCODE4|APPDEGCODE4|APPMAJCODE4|APPPGMCODE4|APPTERM5|');
        utl_file.put(fHand,	'APPNUM5|APPLVLCODE5|APPSTYPCODE5|APPRESD5|APPFPTIME5|');
        utl_file.put(fHand,	'APPDECISION5|APPDECDATE5|APPCAMPUS5|APPCOLLCODE5|APPDEGCODE5|');
        utl_file.put(fHand,	'APPMAJCODE5|APPPGMCODE5|REGTERM|REGLVLCODE|REGSTYPCODE|');
        utl_file.put(fHand,	'REGRESD|REGFPTIME|REGCAMPUS|REGCOLLEGE|REGDEGREE|REGMAJOR|REGPROGRAM|');
        utl_file.put(fHand, 'LASTTERMENROLLED|GPALVL1|GPALVL2|GPALVL3|GPALVL4|FUNDSOURCE|EXTERNALEMAIL|');
        
        
        -- We will send only 5 fields because 
        
        --utl_file.put(fHand, 'REGDEPTCODE|REGMAJORCONCCODE|APPDEPTCODE1|APPDEPTCODE2|APPDEPTCODE3|APPDEPTCODE4|APPDEPTCODE5|');
        --utl_file.put(fHand, 'APPMAJORCONCCODE1|APPMAJORCONCCODE2|APPMAJORCONCCODE3|APPMAJORCONCCODE4|APPMAJORCONCCODE5|');
        --utl_file.put_line(fHand, 'APPLDATE1|APPLDATE2|APPLDATE3|APPLDATE4|APPLDATE5');
        
        utl_file.put_line(fHand, 'REGDEPTCODE|REGMAJORCONCCODE|APPDEPTCODE1|APPMAJORCONCCODE1|APPLDATE1');

        --Student data query loop.
        for student in 
        (
            --Query all student data records.
            select SZBSYMS_USERNAME,
                   SZBSYMS_STUDENTID,
                   SZBSYMS_FIRSTNAME,
                   SZBSYMS_LASTNAME,
                   SZBSYMS_FULLNAME,
                   SZBSYMS_MIDDLENAME,
                   SZBSYMS_PREFNAME,
                   SZBSYMS_EMAIL,
                   SZBSYMS_PHONE,
                   SZBSYMS_BIRTHDATE,
                   SZBSYMS_GENDER,
                   SZBSYMS_PRONOUN,
                   SZBSYMS_ETHNICITY,
                   SZBSYMS_CITIZENSHIP,
                   SZBSYMS_PERMSTREETLINE1,
                   SZBSYMS_PERMSTREETLINE2,
                   SZBSYMS_PERMSTREETLINE3,
                   SZBSYMS_PERMCITY,
                   SZBSYMS_PERMPROV,
                   SZBSYMS_PERMPOSTCODE,
                   SZBSYMS_PERMCOUNTRY,
                   SZBSYMS_CURRSTREETLINE1,
                   SZBSYMS_CURRSTREETLINE2,
                   SZBSYMS_CURRSTREETLINE3,
                   SZBSYMS_CURRCITY,
                   SZBSYMS_CURRPROV,
                   SZBSYMS_CURRPOSTCODE,
                   SZBSYMS_CURRCOUNTRY,
                   SZBSYMS_DISABILITY,
                   SZBSYMS_EMRCONTFNAME,
                   SZBSYMS_EMRCONTLNAME,
                   SZBSYMS_EMRCONTRELTN,
                   SZBSYMS_EMRCONTPHONE,
                   SZBSYMS_RECTYPE,
                   SZBSYMS_APPTERM1,
                   SZBSYMS_APPNUM1,
                   SZBSYMS_APPLVLCODE1,
                   SZBSYMS_APPSTYPCODE1,
                   SZBSYMS_APPRESD1,
                   SZBSYMS_APPFPTIME1,
                   SZBSYMS_APPDECISION1,
                   SZBSYMS_APPDECDATE1,
                   SZBSYMS_APPLDATE1,
                   SZBSYMS_APPCAMPUS1,
                   SZBSYMS_APPCOLLCODE1,
                   SZBSYMS_APPDEGCODE1,
                   SZBSYMS_APPMAJCODE1,
                   SZBSYMS_APPPGMCODE1,
                   SZBSYMS_APPDEPTCODE1,
                   SZBSYMS_APPMAJORCONCCODE1,
                   SZBSYMS_APPTERM2,
                   SZBSYMS_APPNUM2,
                   SZBSYMS_APPLVLCODE2,
                   SZBSYMS_APPSTYPCODE2,
                   SZBSYMS_APPRESD2,
                   SZBSYMS_APPFPTIME2,
                   SZBSYMS_APPDECISION2,
                   SZBSYMS_APPDECDATE2,
                   SZBSYMS_APPLDATE2,
                   SZBSYMS_APPCAMPUS2,
                   SZBSYMS_APPCOLLCODE2,
                   SZBSYMS_APPDEGCODE2,
                   SZBSYMS_APPMAJCODE2,
                   SZBSYMS_APPPGMCODE2,
                   SZBSYMS_APPDEPTCODE2,
                   SZBSYMS_APPMAJORCONCCODE2,
                   SZBSYMS_APPTERM3,
                   SZBSYMS_APPNUM3,
                   SZBSYMS_APPLVLCODE3,
                   SZBSYMS_APPSTYPCODE3,
                   SZBSYMS_APPRESD3,
                   SZBSYMS_APPFPTIME3,
                   SZBSYMS_APPDECISION3,
                   SZBSYMS_APPDECDATE3,
                   SZBSYMS_APPLDATE3,
                   SZBSYMS_APPCAMPUS3,
                   SZBSYMS_APPCOLLCODE3,
                   SZBSYMS_APPDEGCODE3,
                   SZBSYMS_APPMAJCODE3,
                   SZBSYMS_APPPGMCODE3,
                   SZBSYMS_APPDEPTCODE3,
                   SZBSYMS_APPMAJORCONCCODE3,
                   SZBSYMS_APPTERM4,
                   SZBSYMS_APPNUM4,
                   SZBSYMS_APPLVLCODE4,
                   SZBSYMS_APPSTYPCODE4,
                   SZBSYMS_APPRESD4,
                   SZBSYMS_APPFPTIME4,
                   SZBSYMS_APPDECISION4,
                   SZBSYMS_APPDECDATE4,
                   SZBSYMS_APPLDATE4,
                   SZBSYMS_APPCAMPUS4,
                   SZBSYMS_APPCOLLCODE4,
                   SZBSYMS_APPDEGCODE4,
                   SZBSYMS_APPMAJCODE4,
                   SZBSYMS_APPPGMCODE4,
                   SZBSYMS_APPDEPTCODE4,
                   SZBSYMS_APPMAJORCONCCODE4,
                   SZBSYMS_APPTERM5,
                   SZBSYMS_APPNUM5,
                   SZBSYMS_APPLVLCODE5,
                   SZBSYMS_APPSTYPCODE5,
                   SZBSYMS_APPRESD5,
                   SZBSYMS_APPFPTIME5,
                   SZBSYMS_APPDECISION5,
                   SZBSYMS_APPDECDATE5,
                   SZBSYMS_APPLDATE5,
                   SZBSYMS_APPCAMPUS5,
                   SZBSYMS_APPCOLLCODE5,
                   SZBSYMS_APPDEGCODE5,
                   SZBSYMS_APPMAJCODE5,
                   SZBSYMS_APPPGMCODE5,
                   SZBSYMS_APPDEPTCODE5,
                   SZBSYMS_APPMAJORCONCCODE5,
                   SZBSYMS_REGTERM,
                   SZBSYMS_REGLVLCODE,
                   SZBSYMS_REGSTYPCODE,
                   SZBSYMS_REGRESD,
                   SZBSYMS_REGFPTIME,
                   SZBSYMS_REGCAMPUS,
                   SZBSYMS_REGCOLLEGE,
                   SZBSYMS_REGDEGREE,
                   SZBSYMS_REGMAJOR,
                   SZBSYMS_REGPROGRAM,
                   SZBSYMS_REGDEPTCODE,
                   SZBSYMS_REGMAJORCONCCODE,
                   SZBSYMS_LASTTERMENROLLED,
                   SZBSYMS_GPALVL1,
                   SZBSYMS_GPALVL2,
                   SZBSYMS_GPALVL3,
                   SZBSYMS_GPALVL4,
                   SZBSYMS_FUNDSOURCE,
				   case when SZBSYMS_EXTERNALEMAIL like '%|%' then NULL --dont allow emails with pipe characters, they would break the file (unlikely these would exist)
					    else SZBSYMS_EXTERNALEMAIL
				   end as SZBSYMS_EXTERNALEMAIL	--RFC 561753 - NTOURNEY - 21-FEB-2023
            from SZBSYMS
			where SZBSYMS_ACTIVITYDATE >= to_date('01-JUL-2023') --RFC 561854 NTOURNEY 09-MAY-2023
        ) loop

        --Write student data record to text file.        
        utl_file.put_line(fHand, student.SZBSYMS_USERNAME || '|' ||
                                 student.SZBSYMS_STUDENTID || '|' ||
                                 student.SZBSYMS_FIRSTNAME || '|' ||
                                 student.SZBSYMS_LASTNAME || '|' ||
                                 student.SZBSYMS_FULLNAME || '|' ||
                                 student.SZBSYMS_MIDDLENAME || '|' ||
                                 student.SZBSYMS_PREFNAME || '|' ||
                                 student.SZBSYMS_EMAIL || '|' ||
                                 student.SZBSYMS_PHONE || '|' ||
                                 to_char(student.SZBSYMS_BIRTHDATE, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_GENDER || '|' ||
                                 student.SZBSYMS_PRONOUN || '|' ||
                                 student.SZBSYMS_ETHNICITY || '|' ||
                                 student.SZBSYMS_CITIZENSHIP || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE1 || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE2 || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE3 || '|' ||
                                 student.SZBSYMS_PERMCITY || '|' ||
                                 student.SZBSYMS_PERMPROV || '|' ||
                                 student.SZBSYMS_PERMPOSTCODE || '|' ||
                                 student.SZBSYMS_PERMCOUNTRY || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE1 || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE2 || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE3 || '|' ||
                                 student.SZBSYMS_CURRCITY || '|' ||
                                 student.SZBSYMS_CURRPROV || '|' ||
                                 student.SZBSYMS_CURRPOSTCODE || '|' ||
                                 student.SZBSYMS_CURRCOUNTRY || '|' ||
                                 student.SZBSYMS_DISABILITY || '|' ||
                                 student.SZBSYMS_EMRCONTFNAME || '|' ||
                                 student.SZBSYMS_EMRCONTLNAME || '|' ||
                                 student.SZBSYMS_EMRCONTRELTN || '|' ||
                                 student.SZBSYMS_EMRCONTPHONE || '|' ||
                                 student.SZBSYMS_RECTYPE || '|' ||
                                 student.SZBSYMS_APPTERM1 || '|' ||
                                 student.SZBSYMS_APPNUM1 || '|' ||
                                 student.SZBSYMS_APPLVLCODE1 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE1 || '|' ||
                                 student.SZBSYMS_APPRESD1 || '|' ||
                                 student.SZBSYMS_APPFPTIME1 || '|' ||
                                 student.SZBSYMS_APPDECISION1 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE1, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS1 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE1 || '|' ||
                                 student.SZBSYMS_APPDEGCODE1 || '|' ||
                                 student.SZBSYMS_APPMAJCODE1 || '|' ||
                                 student.SZBSYMS_APPPGMCODE1 || '|' ||
                                 student.SZBSYMS_APPTERM2 || '|' ||
                                 student.SZBSYMS_APPNUM2 || '|' ||
                                 student.SZBSYMS_APPLVLCODE2 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE2 || '|' ||
                                 student.SZBSYMS_APPRESD2 || '|' ||
                                 student.SZBSYMS_APPFPTIME2 || '|' ||
                                 student.SZBSYMS_APPDECISION2 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE2, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS2 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE2 || '|' ||
                                 student.SZBSYMS_APPDEGCODE2 || '|' ||
                                 student.SZBSYMS_APPMAJCODE2 || '|' ||
                                 student.SZBSYMS_APPPGMCODE2 || '|' ||
                                 student.SZBSYMS_APPTERM3 || '|' ||
                                 student.SZBSYMS_APPNUM3 || '|' ||
                                 student.SZBSYMS_APPLVLCODE3 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE3 || '|' ||
                                 student.SZBSYMS_APPRESD3 || '|' ||
                                 student.SZBSYMS_APPFPTIME3 || '|' ||
                                 student.SZBSYMS_APPDECISION3 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE3, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS3 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE3 || '|' ||
                                 student.SZBSYMS_APPDEGCODE3 || '|' ||
                                 student.SZBSYMS_APPMAJCODE3 || '|' ||
                                 student.SZBSYMS_APPPGMCODE3 || '|' ||
                                 student.SZBSYMS_APPTERM4 || '|' ||
                                 student.SZBSYMS_APPNUM4 || '|' ||
                                 student.SZBSYMS_APPLVLCODE4 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE4 || '|' ||
                                 student.SZBSYMS_APPRESD4 || '|' ||
                                 student.SZBSYMS_APPFPTIME4 || '|' ||
                                 student.SZBSYMS_APPDECISION4 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE4, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS4 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE4 || '|' ||
                                 student.SZBSYMS_APPDEGCODE4 || '|' ||
                                 student.SZBSYMS_APPMAJCODE4 || '|' ||
                                 student.SZBSYMS_APPPGMCODE4 || '|' ||
                                 student.SZBSYMS_APPTERM5 || '|' ||
                                 student.SZBSYMS_APPNUM5 || '|' ||
                                 student.SZBSYMS_APPLVLCODE5 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE5 || '|' ||
                                 student.SZBSYMS_APPRESD5 || '|' ||
                                 student.SZBSYMS_APPFPTIME5 || '|' ||
                                 student.SZBSYMS_APPDECISION5 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE5, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS5 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE5 || '|' ||
                                 student.SZBSYMS_APPDEGCODE5 || '|' ||
                                 student.SZBSYMS_APPMAJCODE5 || '|' ||
                                 student.SZBSYMS_APPPGMCODE5 || '|' ||
                                 student.SZBSYMS_REGTERM || '|' ||
                                 student.SZBSYMS_REGLVLCODE || '|' ||
                                 student.SZBSYMS_REGSTYPCODE || '|' ||
                                 student.SZBSYMS_REGRESD || '|' ||
                                 student.SZBSYMS_REGFPTIME || '|' ||
                                 student.SZBSYMS_REGCAMPUS || '|' ||
                                 student.SZBSYMS_REGCOLLEGE || '|' ||
                                 student.SZBSYMS_REGDEGREE || '|' ||
                                 student.SZBSYMS_REGMAJOR || '|' ||
                                 student.SZBSYMS_REGPROGRAM || '|' ||
                                 student.SZBSYMS_LASTTERMENROLLED || '|' ||
                                 student.SZBSYMS_GPALVL1 || '|' ||
                                 student.SZBSYMS_GPALVL2 || '|' ||
                                 student.SZBSYMS_GPALVL3 || '|' ||
                                 student.SZBSYMS_GPALVL4 || '|' ||
                                 student.SZBSYMS_FUNDSOURCE || '|' ||
								 student.SZBSYMS_EXTERNALEMAIL || '|' ||
								 
								 student.SZBSYMS_REGDEPTCODE || '|' ||
                                 student.SZBSYMS_REGMAJORCONCCODE || '|' ||
								 student.SZBSYMS_APPDEPTCODE1 || '|' ||
								 student.SZBSYMS_APPMAJORCONCCODE1 || '|' ||
								 to_char(student.SZBSYMS_APPLDATE1, 'MM/DD/YYYY') 
								 ); --RFC 561753 - NTOURNEY - 21-FEB-2023

    --    if faculty.SZBSIMF_PROGDESC is not null then
    --        utl_file.put(fHand, '"' || faculty.SZBSIMF_PROGDESC || '",');
    --        
    --    else
    --        utl_file.put(fHand, faculty.SZBSIMF_PROGDESC || ',');
    --        
    --    end if;
    --    
    --    if faculty.SZBSIMF_SCHOOL is not null then
    --        utl_file.put(fHand, '"' || faculty.SZBSIMF_SCHOOL || '",');
    --        
    --    else
    --        utl_file.put(fHand, faculty.SZBSIMF_SCHOOL || ',');
    --        
    --    end if;
        
        end loop;
        
        --Close text file.
        utl_file.fclose(fHand);

    --Delta load type is generated daily (Monday to Thursday night).            
    else
        --Create and open delta student data text file.
        fName := 'studentDataDelta_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);
        
        --Generate column headers.
        utl_file.put(fHand, 'USERNAME|STUDENTID|FIRSTNAME|LASTNAME|FULLNAME|');
        utl_file.put(fHand, 'MIDDLENAME|PREFNAME|EMAIL|PHONE|BIRTHDATE|');	
        utl_file.put(fHand, 'GENDER|PRONOUN|ETHNICITY|CITIZENSHIP|PERMSTREETLINE1|');
        utl_file.put(fHand, 'PERMSTREETLINE2|PERMSTREETLINE3|PERMCITY|PERMPROV|');
        utl_file.put(fHand, 'PERMPOSTCODE|PERMCOUNTRY|CURRSTREETLINE1|CURRSTREETLINE2|');
        utl_file.put(fHand, 'CURRSTREETLINE3|CURRCITY|CURRPROV|CURRPOSTCODE|CURRCOUNTRY|');
        utl_file.put(fHand, 'DISABILITY|EMRCONTFNAME|EMRCONTLNAME|EMRCONTRELTN|');
        utl_file.put(fHand, 'EMRCONTPHONE|RECTYPE|APPTERM1|APPNUM1|APPLVLCODE1|');
        utl_file.put(fHand, 'APPSTYPCODE1|APPRESD1|APPFPTIME1|APPDECISION1|APPDECDATE1|');
        utl_file.put(fHand, 'APPCAMPUS1|APPCOLLCODE1|APPDEGCODE1|APPMAJCODE1|APPPGMCODE1|');
        utl_file.put(fHand, 'APPTERM2|APPNUM2|APPLVLCODE2|APPSTYPCODE2|APPRESD2|');
        utl_file.put(fHand, 'APPFPTIME2|APPDECISION2|APPDECDATE2|APPCAMPUS2|APPCOLLCODE2|');
        utl_file.put(fHand, 'APPDEGCODE2|APPMAJCODE2|APPPGMCODE2|APPTERM3|APPNUM3|');
        utl_file.put(fHand,	'APPLVLCODE3|APPSTYPCODE3|APPRESD3|APPFPTIME3|APPDECISION3|');
        utl_file.put(fHand,	'APPDECDATE3|APPCAMPUS3|APPCOLLCODE3|APPDEGCODE3|APPMAJCODE3|');
        utl_file.put(fHand,	'APPPGMCODE3|APPTERM4|APPNUM4|APPLVLCODE4|APPSTYPCODE4|');
        utl_file.put(fHand,	'APPRESD4|APPFPTIME4|APPDECISION4|APPDECDATE4|APPCAMPUS4|');
        utl_file.put(fHand,	'APPCOLLCODE4|APPDEGCODE4|APPMAJCODE4|APPPGMCODE4|APPTERM5|');
        utl_file.put(fHand,	'APPNUM5|APPLVLCODE5|APPSTYPCODE5|APPRESD5|APPFPTIME5|');
        utl_file.put(fHand,	'APPDECISION5|APPDECDATE5|APPCAMPUS5|APPCOLLCODE5|APPDEGCODE5|');
        utl_file.put(fHand,	'APPMAJCODE5|APPPGMCODE5|REGTERM|REGLVLCODE|REGSTYPCODE|');
        utl_file.put(fHand,	'REGRESD|REGFPTIME|REGCAMPUS|REGCOLLEGE|REGDEGREE|REGMAJOR|REGPROGRAM|');
        utl_file.put(fHand, 'LASTTERMENROLLED|GPALVL1|GPALVL2|GPALVL3|GPALVL4|FUNDSOURCE|EXTERNALEMAIL|');
        
        
        -- We will send only 5 fields because 
--        utl_file.put(fHand, 'REGDEPTCODE|REGMAJORCONCCODE|APPDEPTCODE1|APPDEPTCODE2|APPDEPTCODE3|APPDEPTCODE4|APPDEPTCODE5|');
--        utl_file.put(fHand, 'APPMAJORCONCCODE1|APPMAJORCONCCODE2|APPMAJORCONCCODE3|APPMAJORCONCCODE4|APPMAJORCONCCODE5|');
--        utl_file.put_line(fHand, 'APPLDATE1|APPLDATE2|APPLDATE3|APPLDATE4|APPLDATE5');

        utl_file.put_line(fHand, 'REGDEPTCODE|REGMAJORCONCCODE|APPDEPTCODE1|APPMAJORCONCCODE1|APPLDATE1');


        --Student data query loop.        
        for student in 
        (
            --Query student data records generated after today at 8pm.
            select SZBSYMS_USERNAME,
                   SZBSYMS_STUDENTID,
                   SZBSYMS_FIRSTNAME,
                   SZBSYMS_LASTNAME,
                   SZBSYMS_FULLNAME,
                   SZBSYMS_MIDDLENAME,
                   SZBSYMS_PREFNAME,
                   SZBSYMS_EMAIL,
                   SZBSYMS_PHONE,
                   SZBSYMS_BIRTHDATE,
                   SZBSYMS_GENDER,
                   SZBSYMS_PRONOUN,
                   SZBSYMS_ETHNICITY,
                   SZBSYMS_CITIZENSHIP,
                   SZBSYMS_PERMSTREETLINE1,
                   SZBSYMS_PERMSTREETLINE2,
                   SZBSYMS_PERMSTREETLINE3,
                   SZBSYMS_PERMCITY,
                   SZBSYMS_PERMPROV,
                   SZBSYMS_PERMPOSTCODE,
                   SZBSYMS_PERMCOUNTRY,
                   SZBSYMS_CURRSTREETLINE1,
                   SZBSYMS_CURRSTREETLINE2,
                   SZBSYMS_CURRSTREETLINE3,
                   SZBSYMS_CURRCITY,
                   SZBSYMS_CURRPROV,
                   SZBSYMS_CURRPOSTCODE,
                   SZBSYMS_CURRCOUNTRY,
                   SZBSYMS_DISABILITY,
                   SZBSYMS_EMRCONTFNAME,
                   SZBSYMS_EMRCONTLNAME,
                   SZBSYMS_EMRCONTRELTN,
                   SZBSYMS_EMRCONTPHONE,
                   SZBSYMS_RECTYPE,
                   SZBSYMS_APPTERM1,
                   SZBSYMS_APPNUM1,
                   SZBSYMS_APPLVLCODE1,
                   SZBSYMS_APPSTYPCODE1,
                   SZBSYMS_APPRESD1,
                   SZBSYMS_APPFPTIME1,
                   SZBSYMS_APPDECISION1,
                   SZBSYMS_APPDECDATE1,
                   SZBSYMS_APPLDATE1,
                   SZBSYMS_APPCAMPUS1,
                   SZBSYMS_APPCOLLCODE1,
                   SZBSYMS_APPDEGCODE1,
                   SZBSYMS_APPMAJCODE1,
                   SZBSYMS_APPPGMCODE1,
                   SZBSYMS_APPDEPTCODE1,
                   SZBSYMS_APPMAJORCONCCODE1,
                   SZBSYMS_APPTERM2,
                   SZBSYMS_APPNUM2,
                   SZBSYMS_APPLVLCODE2,
                   SZBSYMS_APPSTYPCODE2,
                   SZBSYMS_APPRESD2,
                   SZBSYMS_APPFPTIME2,
                   SZBSYMS_APPDECISION2,
                   SZBSYMS_APPDECDATE2,
                   SZBSYMS_APPLDATE2,
                   SZBSYMS_APPCAMPUS2,
                   SZBSYMS_APPCOLLCODE2,
                   SZBSYMS_APPDEGCODE2,
                   SZBSYMS_APPMAJCODE2,
                   SZBSYMS_APPPGMCODE2,
                   SZBSYMS_APPDEPTCODE2,
                   SZBSYMS_APPMAJORCONCCODE2,
                   SZBSYMS_APPTERM3,
                   SZBSYMS_APPNUM3,
                   SZBSYMS_APPLVLCODE3,
                   SZBSYMS_APPSTYPCODE3,
                   SZBSYMS_APPRESD3,
                   SZBSYMS_APPFPTIME3,
                   SZBSYMS_APPDECISION3,
                   SZBSYMS_APPDECDATE3,
                   SZBSYMS_APPLDATE3,
                   SZBSYMS_APPCAMPUS3,
                   SZBSYMS_APPCOLLCODE3,
                   SZBSYMS_APPDEGCODE3,
                   SZBSYMS_APPMAJCODE3,
                   SZBSYMS_APPPGMCODE3,
                   SZBSYMS_APPDEPTCODE3,
                   SZBSYMS_APPMAJORCONCCODE3,
                   SZBSYMS_APPTERM4,
                   SZBSYMS_APPNUM4,
                   SZBSYMS_APPLVLCODE4,
                   SZBSYMS_APPSTYPCODE4,
                   SZBSYMS_APPRESD4,
                   SZBSYMS_APPFPTIME4,
                   SZBSYMS_APPDECISION4,
                   SZBSYMS_APPDECDATE4,
                   SZBSYMS_APPLDATE4,
                   SZBSYMS_APPCAMPUS4,
                   SZBSYMS_APPCOLLCODE4,
                   SZBSYMS_APPDEGCODE4,
                   SZBSYMS_APPMAJCODE4,
                   SZBSYMS_APPPGMCODE4,
                   SZBSYMS_APPDEPTCODE4,
                   SZBSYMS_APPMAJORCONCCODE4,
                   SZBSYMS_APPTERM5,
                   SZBSYMS_APPNUM5,
                   SZBSYMS_APPLVLCODE5,
                   SZBSYMS_APPSTYPCODE5,
                   SZBSYMS_APPRESD5,
                   SZBSYMS_APPFPTIME5,
                   SZBSYMS_APPDECISION5,
                   SZBSYMS_APPDECDATE5,
                   SZBSYMS_APPLDATE5,
                   SZBSYMS_APPCAMPUS5,
                   SZBSYMS_APPCOLLCODE5,
                   SZBSYMS_APPDEGCODE5,
                   SZBSYMS_APPMAJCODE5,
                   SZBSYMS_APPPGMCODE5,
                   SZBSYMS_APPDEPTCODE5,
                   SZBSYMS_APPMAJORCONCCODE5,
                   SZBSYMS_REGTERM,
                   SZBSYMS_REGLVLCODE,
                   SZBSYMS_REGSTYPCODE,
                   SZBSYMS_REGRESD,
                   SZBSYMS_REGFPTIME,
                   SZBSYMS_REGCAMPUS,
                   SZBSYMS_REGCOLLEGE,
                   SZBSYMS_REGDEGREE,
                   SZBSYMS_REGMAJOR,
                   SZBSYMS_REGPROGRAM,
                   SZBSYMS_REGDEPTCODE,
                   SZBSYMS_REGMAJORCONCCODE,
                   SZBSYMS_LASTTERMENROLLED,
                   SZBSYMS_GPALVL1,
                   SZBSYMS_GPALVL2,
                   SZBSYMS_GPALVL3,
                   SZBSYMS_GPALVL4,
                   SZBSYMS_FUNDSOURCE,
				   case when SZBSYMS_EXTERNALEMAIL like '%|%' then NULL --dont allow emails with pipe characters, they would break the file (unlikely these would exist)
					    else SZBSYMS_EXTERNALEMAIL
				   end as SZBSYMS_EXTERNALEMAIL	--RFC 561753 - NTOURNEY - 21-FEB-2023
            from SZBSYMS
            where SZBSYMS_ACTIVITYDATE > (trunc(sysdate)+5/24) --(sysdate - 0.5)
            --where SZBSYMS_ACTIVITYDATE >= to_date('29-APR-2025') --RFC 561854 NTOURNEY 09-MAY-2023
        ) loop
        
        --Write student class data record to text file.
        utl_file.put_line(fHand, student.SZBSYMS_USERNAME || '|' ||
                                 student.SZBSYMS_STUDENTID || '|' ||
                                 student.SZBSYMS_FIRSTNAME || '|' ||
                                 student.SZBSYMS_LASTNAME || '|' ||
                                 student.SZBSYMS_FULLNAME || '|' ||
                                 student.SZBSYMS_MIDDLENAME || '|' ||
                                 student.SZBSYMS_PREFNAME || '|' ||
                                 student.SZBSYMS_EMAIL || '|' ||
                                 student.SZBSYMS_PHONE || '|' ||
                                 to_char(student.SZBSYMS_BIRTHDATE, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_GENDER || '|' ||
                                 student.SZBSYMS_PRONOUN || '|' ||
                                 student.SZBSYMS_ETHNICITY || '|' ||
                                 student.SZBSYMS_CITIZENSHIP || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE1 || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE2 || '|' ||
                                 student.SZBSYMS_PERMSTREETLINE3 || '|' ||
                                 student.SZBSYMS_PERMCITY || '|' ||
                                 student.SZBSYMS_PERMPROV || '|' ||
                                 student.SZBSYMS_PERMPOSTCODE || '|' ||
                                 student.SZBSYMS_PERMCOUNTRY || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE1 || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE2 || '|' ||
                                 student.SZBSYMS_CURRSTREETLINE3 || '|' ||
                                 student.SZBSYMS_CURRCITY || '|' ||
                                 student.SZBSYMS_CURRPROV || '|' ||
                                 student.SZBSYMS_CURRPOSTCODE || '|' ||
                                 student.SZBSYMS_CURRCOUNTRY || '|' ||
                                 student.SZBSYMS_DISABILITY || '|' ||
                                 student.SZBSYMS_EMRCONTFNAME || '|' ||
                                 student.SZBSYMS_EMRCONTLNAME || '|' ||
                                 student.SZBSYMS_EMRCONTRELTN || '|' ||
                                 student.SZBSYMS_EMRCONTPHONE || '|' ||
                                 student.SZBSYMS_RECTYPE || '|' ||
                                 student.SZBSYMS_APPTERM1 || '|' ||
                                 student.SZBSYMS_APPNUM1 || '|' ||
                                 student.SZBSYMS_APPLVLCODE1 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE1 || '|' ||
                                 student.SZBSYMS_APPRESD1 || '|' ||
                                 student.SZBSYMS_APPFPTIME1 || '|' ||
                                 student.SZBSYMS_APPDECISION1 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE1, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS1 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE1 || '|' ||
                                 student.SZBSYMS_APPDEGCODE1 || '|' ||
                                 student.SZBSYMS_APPMAJCODE1 || '|' ||
                                 student.SZBSYMS_APPPGMCODE1 || '|' ||
                                 student.SZBSYMS_APPTERM2 || '|' ||
                                 student.SZBSYMS_APPNUM2 || '|' ||
                                 student.SZBSYMS_APPLVLCODE2 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE2 || '|' ||
                                 student.SZBSYMS_APPRESD2 || '|' ||
                                 student.SZBSYMS_APPFPTIME2 || '|' ||
                                 student.SZBSYMS_APPDECISION2 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE2, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS2 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE2 || '|' ||
                                 student.SZBSYMS_APPDEGCODE2 || '|' ||
                                 student.SZBSYMS_APPMAJCODE2 || '|' ||
                                 student.SZBSYMS_APPPGMCODE2 || '|' ||
                                 student.SZBSYMS_APPTERM3 || '|' ||
                                 student.SZBSYMS_APPNUM3 || '|' ||
                                 student.SZBSYMS_APPLVLCODE3 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE3 || '|' ||
                                 student.SZBSYMS_APPRESD3 || '|' ||
                                 student.SZBSYMS_APPFPTIME3 || '|' ||
                                 student.SZBSYMS_APPDECISION3 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE3, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS3 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE3 || '|' ||
                                 student.SZBSYMS_APPDEGCODE3 || '|' ||
                                 student.SZBSYMS_APPMAJCODE3 || '|' ||
                                 student.SZBSYMS_APPPGMCODE3 || '|' ||
                                 student.SZBSYMS_APPTERM4 || '|' ||
                                 student.SZBSYMS_APPNUM4 || '|' ||
                                 student.SZBSYMS_APPLVLCODE4 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE4 || '|' ||
                                 student.SZBSYMS_APPRESD4 || '|' ||
                                 student.SZBSYMS_APPFPTIME4 || '|' ||
                                 student.SZBSYMS_APPDECISION4 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE4, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS4 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE4 || '|' ||
                                 student.SZBSYMS_APPDEGCODE4 || '|' ||
                                 student.SZBSYMS_APPMAJCODE4 || '|' ||
                                 student.SZBSYMS_APPPGMCODE4 || '|' ||
                                 student.SZBSYMS_APPTERM5 || '|' ||
                                 student.SZBSYMS_APPNUM5 || '|' ||
                                 student.SZBSYMS_APPLVLCODE5 || '|' ||
                                 student.SZBSYMS_APPSTYPCODE5 || '|' ||
                                 student.SZBSYMS_APPRESD5 || '|' ||
                                 student.SZBSYMS_APPFPTIME5 || '|' ||
                                 student.SZBSYMS_APPDECISION5 || '|' ||
                                 to_char(student.SZBSYMS_APPDECDATE5, 'MM/DD/YYYY') || '|' ||
                                 student.SZBSYMS_APPCAMPUS5 || '|' ||
                                 student.SZBSYMS_APPCOLLCODE5 || '|' ||
                                 student.SZBSYMS_APPDEGCODE5 || '|' ||
                                 student.SZBSYMS_APPMAJCODE5 || '|' ||
                                 student.SZBSYMS_APPPGMCODE5 || '|' ||
                                 
                                 student.SZBSYMS_REGTERM || '|' ||
                                 student.SZBSYMS_REGLVLCODE || '|' ||
                                 student.SZBSYMS_REGSTYPCODE || '|' ||
                                 student.SZBSYMS_REGRESD || '|' ||
                                 student.SZBSYMS_REGFPTIME || '|' ||
                                 student.SZBSYMS_REGCAMPUS || '|' ||
                                 student.SZBSYMS_REGCOLLEGE || '|' ||
                                 student.SZBSYMS_REGDEGREE || '|' ||
                                 student.SZBSYMS_REGMAJOR || '|' ||
                                 student.SZBSYMS_REGPROGRAM || '|' ||
                                 
                                 student.SZBSYMS_LASTTERMENROLLED || '|' ||
                                 student.SZBSYMS_GPALVL1 || '|' ||
                                 student.SZBSYMS_GPALVL2 || '|' ||
                                 student.SZBSYMS_GPALVL3 || '|' ||
                                 student.SZBSYMS_GPALVL4 || '|' ||
                                 student.SZBSYMS_FUNDSOURCE || '|' ||
								 student.SZBSYMS_EXTERNALEMAIL || '|' ||
								 
								 student.SZBSYMS_REGDEPTCODE || '|' ||
                                 student.SZBSYMS_REGMAJORCONCCODE || '|' ||
								 student.SZBSYMS_APPDEPTCODE1 || '|' ||
								 student.SZBSYMS_APPMAJORCONCCODE1 || '|' ||
								 to_char(student.SZBSYMS_APPLDATE1, 'MM/DD/YYYY') 
								 ); 
        
        end loop;
        
        --Close text file.
        utl_file.fclose(fHand);

    end if;


END writesymplicityStudentData;
/
