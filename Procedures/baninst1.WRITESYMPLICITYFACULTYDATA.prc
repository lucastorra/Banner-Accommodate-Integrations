CREATE OR REPLACE PROCEDURE BANINST1.writeSymplicityFacultyData(loadType in varchar2) is

/******************************************************************************
   NAME:       writeSymplicityFacultyData
   PURPOSE:    Symplicity Accommodate Faculty XML File Creation
               This procedure writes the facilty data feed text file with data from the SZBSYMF table.

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
											
   1.1		  09-MAY-2023 Nigel Tourney		RFC 561854 - Changed full file to only pull changes since 01-JUL-2022
   
   1.2		  31-OCT-2023 Nigel Tourney		RFC 562054 - Revised change from RFC 561854 to pull all faculty records with
														 a current assignment.
														 
   1.3        06-NOV-2025 Nigel Tourney     RFC 562894 - Increase minimum academic term from 202300 to 202400
   
   1.4        16-NOV-2025 Lucas Torra       ticket 3875078 - Increase minimum academic term from 202400 to 202500

											
******************************************************************************/
    
    fHand   UTL_FILE.file_type;
    fName   varchar2(50);
    

BEGIN
    --Full load type is generated once per week (Sunday night).
    if loadType = 'F' then
        --Create and open full faculty data text file.
        fName := 'facultyDataFull_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);

        --Generate column headers.    
        utl_file.put(fHand, 'FACULTYID|USERNAME|FIRSTNAME|LASTNAME|FULLNAME|MIDDLENAME|EMAIL|PHONE|');
        utl_file.put_line(fHand, 'FACTYPE|PROGDESC|SCHOOL|CAMPUS|STARTDATE');
        
--        utl_file.put_line(fHand, loadType);

        --Faculty data query loop.        
        for faculty in 
        (
            --Query all faculty data records.
            select SZBSYMF_FACULTYID,
                   SZBSYMF_USERNAME,
                   SZBSYMF_FIRSTNAME,
                   SZBSYMF_LASTNAME,
                   SZBSYMF_FULLNAME,
                   SZBSYMF_MIDDLENAME,
                   SZBSYMF_EMAIL,
                   SZBSYMF_PHONE,
                   SZBSYMF_FACTYPE,
                   SZBSYMF_PROGDESC,
                   SZBSYMF_SCHOOL,
                   SZBSYMF_CAMPUS,
                   SZBSYMF_STARTDATE               
            from SZBSYMF
			--where SZBSYMF_ACTIVITYDATE >= to_date('01-JUL-2022') --RFC 561854 NTOURNEY 09-MAY-2023
			
			--RFC 562054 NTOURNEY 31-OCT-2023
			--Replaced above where clause with the one below. Above logic was causing some current faculty to be missed if their data hasn't been updated in a while.
			WHERE EXISTS
           (SELECT 1
              FROM sirasgn
             WHERE     sirasgn_term_code > '202500'
                   AND sirasgn_pidm = szbsymf_pidm) --RFC 562054 NTOURNEY 31-OCT-2023
        ) loop

        --Write faculty data record to text file.        
        utl_file.put_line(fHand, faculty.SZBSYMF_FACULTYID || '|' ||
                                 faculty.SZBSYMF_USERNAME || '|' ||
                                 faculty.SZBSYMF_FIRSTNAME || '|' ||
                                 faculty.SZBSYMF_LASTNAME || '|' ||
                                 faculty.SZBSYMF_FULLNAME || '|' ||
                                 faculty.SZBSYMF_MIDDLENAME || '|' ||
                                 faculty.SZBSYMF_EMAIL || '|' ||
                                 faculty.SZBSYMF_PHONE || '|' ||
                                 faculty.SZBSYMF_FACTYPE || '|' ||
                                 faculty.SZBSYMF_PROGDESC || '|' ||
                                 faculty.SZBSYMF_SCHOOL || '|' ||
                                 faculty.SZBSYMF_CAMPUS || '|' ||
                                 to_char(faculty.SZBSYMF_STARTDATE, 'MM/DD/YYYY'));
                         
        end loop;

        --Close text file.
        utl_file.fclose(fHand);

    --Delta load type is generated daily (Monday to Thursday night).            
    else
        --Create and open delta faculty data text file.
        fName := 'facultyDataDelta_' || to_char(sysdate, 'DDMONYYYY') || '.txt';
        fHand := utl_file.fopen('SYMPLICITY_DIR', fName, 'w', 32767);

        --Generate column headers.    
        utl_file.put(fHand, 'FACULTYID|USERNAME|FIRSTNAME|LASTNAME|FULLNAME|MIDDLENAME|EMAIL|PHONE|');
        utl_file.put_line(fHand, 'FACTYPE|PROGDESC|SCHOOL|CAMPUS|STARTDATE');
        
--        utl_file.put_line(fHand, loadType);

        --Faculty data query loop.                
        for faculty in 
        (
            --Query faculty data records generated after today at 8pm.
            select SZBSYMF_FACULTYID,
                   SZBSYMF_USERNAME,
                   SZBSYMF_FIRSTNAME,
                   SZBSYMF_LASTNAME,
                   SZBSYMF_FULLNAME,
                   SZBSYMF_MIDDLENAME,
                   SZBSYMF_EMAIL,
                   SZBSYMF_PHONE,
                   SZBSYMF_FACTYPE,
                   SZBSYMF_PROGDESC,
                   SZBSYMF_SCHOOL,
                   SZBSYMF_CAMPUS,
                   SZBSYMF_STARTDATE               
            from SZBSYMF
            where SZBSYMF_ACTIVITYDATE > (trunc(sysdate)+20/24) --(sysdate - 0.5)
        ) loop
    
        --Write faculty data record to text file.
        utl_file.put_line(fHand, faculty.SZBSYMF_FACULTYID || '|' ||
                                 faculty.SZBSYMF_USERNAME || '|' ||
                                 faculty.SZBSYMF_FIRSTNAME || '|' ||
                                 faculty.SZBSYMF_LASTNAME || '|' ||
                                 faculty.SZBSYMF_FULLNAME || '|' ||
                                 faculty.SZBSYMF_MIDDLENAME || '|' ||
                                 faculty.SZBSYMF_EMAIL || '|' ||
                                 faculty.SZBSYMF_PHONE || '|' ||
                                 faculty.SZBSYMF_FACTYPE || '|' ||
                                 faculty.SZBSYMF_PROGDESC || '|' ||
                                 faculty.SZBSYMF_SCHOOL || '|' ||
                                 faculty.SZBSYMF_CAMPUS || '|' ||
                                 to_char(faculty.SZBSYMF_STARTDATE, 'MM/DD/YYYY'));
                         
        end loop;

        --Close text file.        
        utl_file.fclose(fHand);
    
    end if;
    
             
--    if faculty.SZBSYMF_PROGDESC is not null then
--        utl_file.put(fHand, '"' || faculty.SZBSYMF_PROGDESC || '",');
--        
--    else
--        utl_file.put(fHand, faculty.SZBSYMF_PROGDESC || ',');
--        
--    end if;
--    
--    if faculty.SZBSYMF_SCHOOL is not null then
--        utl_file.put(fHand, '"' || faculty.SZBSYMF_SCHOOL || '",');
--        
--    else
--        utl_file.put(fHand, faculty.SZBSYMF_SCHOOL || ',');
--        
--    end if;


END writeSymplicityFacultyData;
/
