CREATE OR REPLACE PROCEDURE BANINST1.writesymplicityClassData(loadType in varchar2) is

/******************************************************************************
   NAME:       writesymplicityClassData
   PURPOSE:    Symplicity Accommodate Class XML File Creation
               This procedure writes the class data feed text file with data from the SZBSYMC table.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
											
   1.1		  09-MAY-2023 Nigel Tourney		RFC 561854 - Increase minimum academic term from 202100 to 202200
											
******************************************************************************/
    
    fHand   UTL_FILE.file_type;
    fName   varchar2(50);


BEGIN
    --Full load type is generated once per week (Sunday night).
    if loadType = 'F' then
        --Create and open full class data text file.
        fName := 'classDataFull_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);
        
        --Generate column headers.
        utl_file.put(fHand, 'STUDENTID|UNIQCRSEID|CRSETITLE|CRSENUM|STATUS|TERM|INSTREMAIL|');
        utl_file.put(fHand, 'INSTREMAIL2|INSTREMAIL3|INSTREMAIL4|INSTREMAIL5|INSTREMAIL6|INSTREMAIL7|');
        utl_file.put(fHand, 'INSTREMAIL8|INSTREMAIL9|INSTREMAIL10|INSTREMAIL11|INSTREMAIL12|');
        utl_file.put(fHand, 'INSTREMAIL13|INSTREMAIL14|INSTREMAIL15|INSTREMAIL16|INSTREMAIL17|');
        utl_file.put(fHand, 'INSTREMAIL18|INSTREMAIL19|INSTREMAIL20|DAYS|STARTTIME|ENDTIME|STARTDATE|');
        utl_file.put_line(fHand, 'ENDDATE|ENROLLENDDATE|ENROLLED|ENROLLDATE|GRADECODE|GRADEDATE|CREDITHRS');
        
        --Student class data query loop.
        for stuClass in 
        (
            --Query all student class data records.
            select SZBSYMC_STUDENTID,
                   SZBSYMC_UNIQCRSEID,
                   SZBSYMC_CRSETITLE,
                   SZBSYMC_CRSENUM,
                   SZBSYMC_STATUS,
                   SZBSYMC_TERM,
                   SZBSYMC_INSTREMAIL,
                   SZBSYMC_INSTREMAIL2,
                   SZBSYMC_INSTREMAIL3,
                   SZBSYMC_INSTREMAIL4,
                   SZBSYMC_INSTREMAIL5,
                   SZBSYMC_INSTREMAIL6,
                   SZBSYMC_INSTREMAIL7,
                   SZBSYMC_INSTREMAIL8,
                   SZBSYMC_INSTREMAIL9,
                   SZBSYMC_INSTREMAIL10,
                   SZBSYMC_INSTREMAIL11,
                   SZBSYMC_INSTREMAIL12,
                   SZBSYMC_INSTREMAIL13,
                   SZBSYMC_INSTREMAIL14,
                   SZBSYMC_INSTREMAIL15,
                   SZBSYMC_INSTREMAIL16,
                   SZBSYMC_INSTREMAIL17,
                   SZBSYMC_INSTREMAIL18,
                   SZBSYMC_INSTREMAIL19,
                   SZBSYMC_INSTREMAIL20,
                   SZBSYMC_DAYS,
                   SZBSYMC_STARTTIME,
                   SZBSYMC_ENDTIME,
                   SZBSYMC_STARTDATE,
                   SZBSYMC_ENDDATE,
                   SZBSYMC_ENROLLENDDATE,
                   SZBSYMC_ENROLLED,
                   SZBSYMC_ENROLLDATE,
                   SZBSYMC_GRADECODE,
                   SZBSYMC_GRADEDATE,
                   SZBSYMC_CREDITHRS
            from SZBSYMC
			where SZBSYMC_TERM > '202300' --RFC 561854 NTOURNEY 09-MAY-2023
            order by SZBSYMC_UNIQCRSEID, 
                   SZBSYMC_ACTIVITYDATE ASC
        ) loop
        
        --Write student class data record to text file.
        utl_file.put_line(fHand, stuClass.SZBSYMC_STUDENTID || '|' ||
                                 stuClass.SZBSYMC_UNIQCRSEID || '|' ||
                                 stuClass.SZBSYMC_CRSETITLE || '|' ||
                                 stuClass.SZBSYMC_CRSENUM || '|' ||
                                 stuClass.SZBSYMC_STATUS || '|' ||
                                 stuClass.SZBSYMC_TERM || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL2 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL3 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL4 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL5 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL6 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL7 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL8 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL9 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL10 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL11 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL12 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL13 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL14 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL15 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL16 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL17 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL18 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL19 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL20 || '|' ||
                                 stuClass.SZBSYMC_DAYS || '|' ||
                                 stuClass.SZBSYMC_STARTTIME || '|' ||
                                 stuClass.SZBSYMC_ENDTIME || '|' ||
                                 to_char(stuClass.SZBSYMC_STARTDATE, 'MM/DD/YYYY') || '|' ||
                                 to_char(stuClass.SZBSYMC_ENDDATE, 'MM/DD/YYYY') || '|' ||
                                 to_char(stuClass.SZBSYMC_ENROLLENDDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_ENROLLED || '|' ||
                                 to_char(stuClass.SZBSYMC_ENROLLDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_GRADECODE || '|' ||
                                 to_char(stuClass.SZBSYMC_GRADEDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_CREDITHRS);
                             
        end loop;

        --Close text file.
        utl_file.fclose(fHand);
    
    --Delta load type is generated daily (Monday to Thursday night).    
    else
        --Create and open delta class data text file.
        fName := 'classDataDelta_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);
        
        --Generate column headers.
        utl_file.put(fHand, 'STUDENTID|UNIQCRSEID|CRSETITLE|CRSENUM|STATUS|TERM|INSTREMAIL|');
        utl_file.put(fHand, 'INSTREMAIL2|INSTREMAIL3|INSTREMAIL4|INSTREMAIL5|INSTREMAIL6|INSTREMAIL7|');
        utl_file.put(fHand, 'INSTREMAIL8|INSTREMAIL9|INSTREMAIL10|INSTREMAIL11|INSTREMAIL12|');
        utl_file.put(fHand, 'INSTREMAIL13|INSTREMAIL14|INSTREMAIL15|INSTREMAIL16|INSTREMAIL17|');
        utl_file.put(fHand, 'INSTREMAIL18|INSTREMAIL19|INSTREMAIL20|DAYS|STARTTIME|ENDTIME|STARTDATE|');
        utl_file.put_line(fHand, 'ENDDATE|ENROLLENDDATE|ENROLLED|ENROLLDATE|GRADECODE|GRADEDATE|CREDITHRS');
        
        --Student class data query loop.        
        for stuClass in 
        (
            --Query student class data records generated after today at 8pm.
            select SZBSYMC_STUDENTID,
                   SZBSYMC_UNIQCRSEID,
                   SZBSYMC_CRSETITLE,
                   SZBSYMC_CRSENUM,
                   SZBSYMC_STATUS,
                   SZBSYMC_TERM,
                   SZBSYMC_INSTREMAIL,
                   SZBSYMC_INSTREMAIL2,
                   SZBSYMC_INSTREMAIL3,
                   SZBSYMC_INSTREMAIL4,
                   SZBSYMC_INSTREMAIL5,
                   SZBSYMC_INSTREMAIL6,
                   SZBSYMC_INSTREMAIL7,
                   SZBSYMC_INSTREMAIL8,
                   SZBSYMC_INSTREMAIL9,
                   SZBSYMC_INSTREMAIL10,
                   SZBSYMC_INSTREMAIL11,
                   SZBSYMC_INSTREMAIL12,
                   SZBSYMC_INSTREMAIL13,
                   SZBSYMC_INSTREMAIL14,
                   SZBSYMC_INSTREMAIL15,
                   SZBSYMC_INSTREMAIL16,
                   SZBSYMC_INSTREMAIL17,
                   SZBSYMC_INSTREMAIL18,
                   SZBSYMC_INSTREMAIL19,
                   SZBSYMC_INSTREMAIL20,
                   SZBSYMC_DAYS,
                   SZBSYMC_STARTTIME,
                   SZBSYMC_ENDTIME,
                   SZBSYMC_STARTDATE,
                   SZBSYMC_ENDDATE,
                   SZBSYMC_ENROLLENDDATE,
                   SZBSYMC_ENROLLED,
                   SZBSYMC_ENROLLDATE,
                   SZBSYMC_GRADECODE,
                   SZBSYMC_GRADEDATE,
                   SZBSYMC_CREDITHRS
            from SZBSYMC
            where SZBSYMC_ACTIVITYDATE > (trunc(sysdate)+20/24) --(sysdate - 0.5)
			and SZBSYMC_TERM > '202300' --RFC561854 NTOURNEY 09-MAY-2023
            order by SZBSYMC_UNIQCRSEID, 
                   SZBSYMC_ACTIVITYDATE ASC
        ) loop
        
        --Write student class data record to text file.
        utl_file.put_line(fHand, stuClass.SZBSYMC_STUDENTID || '|' ||
                                 stuClass.SZBSYMC_UNIQCRSEID || '|' ||
                                 stuClass.SZBSYMC_CRSETITLE || '|' ||
                                 stuClass.SZBSYMC_CRSENUM || '|' ||
                                 stuClass.SZBSYMC_STATUS || '|' ||
                                 stuClass.SZBSYMC_TERM || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL2 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL3 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL4 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL5 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL6 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL7 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL8 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL9 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL10 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL11 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL12 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL13 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL14 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL15 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL16 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL17 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL18 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL19 || '|' ||
                                 stuClass.SZBSYMC_INSTREMAIL20 || '|' ||
                                 stuClass.SZBSYMC_DAYS || '|' ||
                                 stuClass.SZBSYMC_STARTTIME || '|' ||
                                 stuClass.SZBSYMC_ENDTIME || '|' ||
                                 to_char(stuClass.SZBSYMC_STARTDATE, 'MM/DD/YYYY') || '|' ||
                                 to_char(stuClass.SZBSYMC_ENDDATE, 'MM/DD/YYYY') || '|' ||
                                 to_char(stuClass.SZBSYMC_ENROLLENDDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_ENROLLED || '|' ||
                                 to_char(stuClass.SZBSYMC_ENROLLDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_GRADECODE || '|' ||
                                 to_char(stuClass.SZBSYMC_GRADEDATE, 'MM/DD/YYYY') || '|' ||
                                 stuClass.SZBSYMC_CREDITHRS);
                             
        end loop;

        --Close text file.
        utl_file.fclose(fHand);
        
    end if;
           
                
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
--
--    utl_file.put_line(fHand, faculty.SZBSIMF_CAMPUS || ',' ||
--                             faculty.SZBSIMF_STARTDATE);
    

END writesymplicityClassData;
/
