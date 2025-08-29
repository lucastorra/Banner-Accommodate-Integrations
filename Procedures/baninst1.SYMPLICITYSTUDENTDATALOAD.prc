CREATE OR REPLACE PROCEDURE BANINST1.symplicityStudentDataLoad is

/******************************************************************************
   NAME:       symplicityStudentDataLoad
   PURPOSE:    Symplicity Accommodate Student Data Load
               This procedure pulls student data from various Banner tables and loads it into the SZBSYMS table

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
   
   1.1        21-FEB-2023 Nigel Tourney    	RFC 561753 - Add external email address 
											to Student file
											
   1.2		  09-MAY-2023 Nigel Tourney		RFC 561854 - Increase minimum academic term from 202100 to 202300
   
   1.3		  20-JUL-2023 Nigel Tourney		RFC 561946 - Modify email address field to always use the username@saskpolytech.ca.
											For some students, the data in goremal for IA type is missing or incorrect.
	1.4        23-JAN-2024 Gerry McLellan     Cloned to run single (Multiple) student(s) If changes to main procedure, re-make cloned proceudre (BANINST1.symplicityStudentDataLoad_OneStudent)										

    1.5		  01-OCT-2024 Nigel Tourney		RFC 562440 - Modify the APP$REG update logic to include more fields.
                                            For some reason not all fields get updated for these record types,
                                            so personal info and other fields like last term enrolled are out of
                                            date in Accommodate.
                                            
                                            Modified last term enrolled to rank regular terms higher than con-ed.
											
******************************************************************************/

    stuPidm         number(8);
    --pidm_Parameter  number(8);    -- *** For testing ***

    --Required data
    userName            varchar2(46);  --gobtpac
    studentID           varchar2(9);   --spriden
    firstName           varchar2(60);
    lastName            varchar2(60);
    fullName            varchar2(120);
    middleName          varchar2(60);
    stuEmail            varchar2(128);  --gobtpac
    
    --Optional data
    phoneLength         number(2);  --sprtele
    fullPhone           varchar2(100); --varchar2(18);
    prefName            varchar2(60);  --spbpers
    birthDate           date;         
    gender              varchar2(1);
    pronoun             varchar2(4);
    ethnCode            varchar2(2); 
    ethnicity           varchar2(30);  --stvethn
    citzCode            varchar2(2);
    citzDesc            varchar2(30);  --stvcitz
    permStreetLine1     varchar2(75);  --spraddr
    permStreetLine2     varchar2(75);
    permStreetLine3     varchar2(75);
    permCity            varchar2(50);
    permProv            varchar2(3);
    permPostCode        varchar2(30);
    permCtryCode        varchar2(5);
    permCountry         varchar2(30);  --stvnatn
    currStreetLine1     varchar2(75);
    currStreetLine2     varchar2(75);
    currStreetLine3     varchar2(75);
    currCity            varchar2(50);
    currProv            varchar2(3);
    currPostCode        varchar2(30);
    currCtryCode        varchar2(5);
    currCountry         varchar2(30);
    disabilityStatus    varchar2(30);  --sprmedi_medi_code
    --Disability? - Other fields?
    emrContactFName     varchar2(60);  --spremrg
    emrContactLName     varchar2(60);
    emrContactReltn     varchar2(30);
    emrContactPhone     varchar2(18);
    recordType          varchar2(10);
    termCode            varchar2(6);
    appNum              number(2);
    lvlCode             varchar2(2);
    lvlDesc             varchar2(30);
    sTypCode            varchar2(1);
    sTypDesc            varchar2(30);
    resdCode            varchar2(30);  --stvresd
    fPTimeInd           varchar2(1);
    appDecision         varchar2(2);  --szvaprd/sarappd
    appDecisionDesc     varchar2(30);
    appDecDate          date;
	applDate            date;
--    regResd             varchar2(30);
    campus              varchar2(30);  --szvaprd
--    campusOld           varchar2(30);
--    campusNew           varchar2(30);
    collegeCode         varchar2(100);  --varchar2(30);
    degreeCode          varchar2(30);
    majorCode           varchar2(30);
    programCode         varchar2(12);
	deptDesc            VARCHAR2(30);
	majorConcDesc       VARCHAR2(40);
    lastTermEnrolled    varchar2(6);
    gpaLvl1             number(23,9);
    gpaLvl2             number(23,9);
    gpaLvl3             number(23,9);
    gpaLvl4             number(23,9);
    fundSrcCode         varchar2(4);
    fundSrcDesc         varchar2(30);
	externalEmail		GENERAL.GOREMAL.GOREMAL_EMAIL_ADDRESS%type;
    
 
    --Exception email
    l_status            varchar2(20);
    frm_add             varchar2(128);
    to_add              varchar2(128) := 'JProgramAnalyst@saskpolytech.ca';
    cc_add              varchar2(128):= 'lop@saskpolytech.ca';
    subjct              varchar2(150);
    msg                 varchar2(10000);
    
--    emailCnt        number;
--    phoneCnt        number;
--    disabledCount   number;
    appInsertSZR        varchar2(1);
    regInsertSZR        varchar2(1);
    idExist             number;
    toInsertUpdate      varchar2(1);
    toUpdate            varchar2(1);
    toUpdateSZR         varchar2(1);

--    cnt             number := 0;
--    gpa1Cnt         number(2);
--    gpa2Cnt         number(2);
--    gpa3Cnt         number(2);
--    gpa4Cnt         number(2);


    cursor getApps_c(c_pidm number) is

        select * 
		  from INTSERV.SPT_SYMP_SZVAPRD
		 where szvaprd_term_code_entry > '202300'
           and szvaprd_apdc_code in ('AA','BA','CA','ER','EX','IA','IT','LA','OR','QE','RA','RF','RO','RU','TR','WA','WC','WL')
           and szvaprd_pidm = c_pidm
           --and szvaprd_pidm = pidm_Parameter  --**********for testing********* 
         order by 2,1,3;      
        
    getApps_rec    getApps_c%rowtype;
    
    
    cursor getAppsPidm_c is

        select distinct szvaprd_pidm 
          from SZVAPRD 
         where szvaprd_term_code_entry > '202300'
          --and szvaprd_pidm in pidm_Parameter  --**********for testing*********
        and szvaprd_apdc_code in ('AA','BA','CA','ER','EX','IA','IT','LA','OR','QE','RA','RF','RO','RU','TR','WA','WC','WL')
        order by 1
        ;        
--        select distinct szvaprd_pidm from SZVAPRD where szvaprd_term_code_entry > '202001' --'202000'
--        and szvaprd_term_code_entry < '202003' --'202100'
--        and szvaprd_apdc_code in ('AA','BA','CA','ER','EX','IA','IT','LA','OR','QE','RA','RF','RO','RU','TR','WA','WC','WL')
--        order by 1;

    getAppsPidm_rec    getAppsPidm_c%rowtype;
    
    
    cursor getCurrAddr_c(c_pidm number) is
        
        select spraddr_street_line1,
               spraddr_street_line2,
               spraddr_street_line3,
               spraddr_city,
               spraddr_stat_code,
               spraddr_zip,
               spraddr_natn_code
        from SPRADDR where spraddr_pidm = c_pidm
        and spraddr_atyp_code = 'CR'
        and spraddr_status_ind is null
        and spraddr_to_date is null;
    
    getCurrAddr_rec    getCurrAddr_c%rowtype;
    
    
    cursor getEmrContact_c(c_pidm number) is
       
        select spremrg_first_name,
               spremrg_last_name,
               DECODE(spremrg_relt_code,'S','Significant Other',
                                        'P','Parent',
                                        'G','Guardian',
                                        'F','Other Family',
                                        'N','Non-Family') spremrg_relt_code,
               spremrg_phone_area,
               spremrg_phone_number
        from spremrg where spremrg_pidm = c_pidm
        and spremrg_priority = 1;
    
    getEmrContact_rec   getEmrContact_c%rowtype;
    
    
    cursor getExistingRec_c(c_pidm number) is
        
        select * from szbsyms
        where szbsyms_pidm = c_pidm;
    
    getExistingRec_rec        getExistingRec_c%rowtype;
    
    
    cursor getNewSZBApp_c(c_stuPidm number) is
    
        select 'NA' newAppRec 
        from szbsyms
        where szbsyms_pidm = c_stuPidm
        and szbsyms_rectype = 'APP'
        and szbsyms_adddate > sysdate - 1/48;
        
    getNewSZBApp_rec           getNewSZBApp_c%rowtype;
    
    
    cursor getPermAddr_c(c_pidm number) is
        
        select spraddr_street_line1,
               spraddr_street_line2,
               spraddr_street_line3,
               spraddr_city,
               spraddr_stat_code,
               spraddr_zip,
               spraddr_natn_code
        from SPRADDR where spraddr_pidm = c_pidm
        and spraddr_atyp_code = 'PR'
        and spraddr_status_ind is null
        and spraddr_to_date is null;
    
    getPermAddr_rec    getPermAddr_c%rowtype;
    
    
    cursor getRegs_c(c_pidm number) is
    
        SELECT CASE WHEN SZVESTU_PROGRAM_1 != 'NONPRGM' THEN TO_NUMBER(SZVESTU_ETRM_CODE) + 20
				ELSE TO_NUMBER(SZVESTU_ETRM_CODE) 
               END AS ETRM_SORT_PRIORITY, --NTOURNEY 25-NOV-2023 added this to prioritize terms with programs defined
               SZVESTU_ETRM_CODE,
               SZVESTU_LEVL_CODE,
               SZVESTU_STYP_CODE,
               SZVESTU_PROGRAM_1,
               SZVESTU_CAMP_CODE,
               SZVESTU_FULL_PART_IND,
               SZVESTU_RESD_CODE,
               SZVESTU_COLL_CODE_1,
               SZVESTU_DEGC_CODE_1,
               SZVESTU_MAJR_CODE_1,
			   SZVESTU_DEPT_CODE,
			   SZVESTU_MAJR_CODE_CONC_1
        FROM SZVESTU
        WHERE SZVESTU_ETRM_CODE > '202300' --'202000'
        AND SZVESTU_PIDM = C_PIDM
        order by 1 desc; -- Adjusted back to 2022 code. Lucas Torra 2025-08-15
        
    getRegs_rec     getRegs_c%rowtype;
    
    
    cursor getRegsPidm_c is

        select distinct szvstcr_pidm from saturn.szvstcr where szvstcr_term_code > '202300'
        
          --and szvstcr_pidm = pidm_Parameter --**********for testing*********
        order by 1
        ; 
--        select distinct szvstcr_pidm from szvstcr where szvstcr_term_code > '202001' --'202000'
--        and szvstcr_term_code < '202003'; --'202100'

    getRegsPidm_rec     getRegsPidm_c%rowtype;
    
    
    cursor getSameAppRec_c(c_stuPidm number, c_userName varchar2, c_studentID varchar2, c_fName varchar2, c_lName varchar2, c_fullName varchar2, 
                    c_mName varchar2, c_prefName varchar2, c_email varchar2, c_phone varchar2, c_birthDate date, c_gender varchar2, c_pronoun varchar2, 
                    c_ethnicity varchar2, c_citzDesc varchar2, c_permStreetLine1 varchar2, c_permStreetLine2 varchar2,  c_permStreetLine3 varchar2,  c_permCity varchar2,   
                    c_permProv varchar2, c_permPostCode varchar2,  c_permCountry varchar2,  c_currStreetLine1 varchar2,  c_currStreetLine2 varchar2, 
                    c_currStreetLine3 varchar2, c_currCity varchar2, c_currProv varchar2,  c_currPostCode varchar2,  c_currCountry varchar2, c_emrContactFName varchar2, 
                    c_emrContactLName varchar2, c_emrContactReltn varchar2, c_emrContactPhone varchar2, c_disabilityStatus varchar2, c_recordType varchar2,
                    c_appTermCode varchar2, c_appNum number, c_appLvlCode varchar2, c_appSTypCode varchar2, c_appResd varchar2, c_appFPTime varchar2, 
                    c_appDecision varchar2, c_appDecDate date, c_applDate date, c_campus varchar2, c_collegeCode varchar2, c_degreeCode varchar2, c_majorCode  varchar2, 
                    c_programCode varchar2, c_deptDesc varchar2, c_majorConcDesc varchar2, c_lastTermEnrolled varchar2, c_gpaLvl1 number, 
                    c_gpaLvl2 number, c_gpaLvl3 number, c_gpaLvl4 number, c_fundSrc varchar2, c_externalEmail varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_username,'~') = nvl(c_userName,'~') 
        and nvl(szbsyms_studentID,'~') = nvl(c_studentID,'~') 
        and nvl(szbsyms_firstname,'~') = nvl(c_fName,'~') 
        and nvl(szbsyms_lastname,'~') = nvl(c_lName,'~')
        and nvl(szbsyms_fullname,'~') = nvl(c_fullName,'~')        
        and nvl(szbsyms_middlename,'~') = nvl(c_mName,'~')
        and nvl(szbsyms_prefname,'~') = nvl(c_prefName,'~')       
        and nvl(szbsyms_email,'~') = nvl(c_email,'~')
        and nvl(szbsyms_phone,'~') = nvl(c_phone,'~')
        and to_date(nvl(to_char(szbsyms_birthdate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_birthDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_gender,'~') = nvl(c_gender,'~')
        and nvl(szbsyms_pronoun,'~') = nvl(c_pronoun,'~')
        and nvl(szbsyms_ethnicity,'~') = nvl(c_ethnicity,'~')
        and nvl(szbsyms_citizenship,'~') = nvl(c_citzDesc,'~')
        and nvl(szbsyms_permstreetline1,'~') = nvl(c_permStreetLine1,'~')
        and nvl(szbsyms_permstreetline2,'~') = nvl(c_permStreetLine2,'~')
        and nvl(szbsyms_permstreetline3,'~') = nvl(c_permStreetLine3,'~')
        and nvl(szbsyms_permcity,'~') = nvl(c_permCity,'~')
        and nvl(szbsyms_permprov,'~') = nvl(c_permProv,'~') 
        and nvl(szbsyms_permpostcode,'~') = nvl(c_permPostCode,'~') 
        and nvl(szbsyms_permcountry,'~') = nvl(c_permCountry,'~') 
        and nvl(szbsyms_currstreetline1,'~') = nvl(c_currStreetLine1,'~') 
        and nvl(szbsyms_currstreetline2,'~') = nvl(c_currStreetLine2,'~') 
        and nvl(szbsyms_currstreetline3,'~') = nvl(c_currStreetLine3,'~') 
        and nvl(szbsyms_currcity,'~') = nvl(c_currCity,'~') 
        and nvl(szbsyms_currprov,'~') = nvl(c_currProv,'~') 
        and nvl(szbsyms_currpostcode,'~') = nvl(c_currPostCode,'~') 
        and nvl(szbsyms_currcountry,'~') = nvl(c_currCountry,'~') 
        and nvl(szbsyms_emrcontfname,'~') = nvl(c_emrContactFName,'~') 
        and nvl(szbsyms_emrcontlname,'~') = nvl(c_emrContactLName,'~') 
        and nvl(szbsyms_emrcontreltn,'~') = nvl(c_emrContactReltn,'~') 
        and nvl(szbsyms_emrcontphone,'~') = nvl(c_emrContactPhone,'~') 
        and nvl(szbsyms_disability,'~') = nvl(c_disabilityStatus,'~') 
--        and nvl(szbsyms_rectype,'~') = nvl(c_recordType,'~') 
        and nvl(szbsyms_appterm1,'~') = nvl(c_appTermCode,'~') 
        and nvl(to_char(szbsyms_appnum1),'~') = nvl(to_char(c_appNum),'~')
        and nvl(szbsyms_applvlcode1,'~') = nvl(c_appLvlCode,'~') 
        and nvl(szbsyms_appstypcode1,'~') = nvl(c_appSTypCode,'~') 
        and nvl(szbsyms_appresd1,'~') = nvl(c_appResd,'~') 
        and nvl(szbsyms_appfptime1,'~') = nvl(c_appFPTime,'~') 
        and nvl(szbsyms_appdecision1,'~') = nvl(c_appDecision,'~') 
        and to_date(nvl(to_char(szbsyms_appdecdate1,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_appDecDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsyms_appldate1,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_applDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_appcampus1,'~') = nvl(c_campus,'~') 
        and nvl(szbsyms_appcollcode1,'~') = nvl(c_collegeCode,'~') 
        and nvl(szbsyms_appdegcode1,'~') = nvl(c_degreeCode,'~') 
        and nvl(szbsyms_appmajcode1,'~') = nvl(c_majorCode,'~') 
        and nvl(szbsyms_apppgmcode1,'~') = nvl(c_programCode,'~')
        and nvl(szbsyms_appdeptcode1,'~') = nvl(c_deptDesc,'~')
        and nvl(szbsyms_appmajorconccode1,'~') = nvl(c_majorConcDesc,'~')
        and nvl(szbsyms_lasttermenrolled,'~') = nvl(c_lastTermEnrolled,'~')
        and nvl(to_char(szbsyms_gpalvl1),'~') = nvl(to_char(c_gpaLvl1),'~')
        and nvl(to_char(szbsyms_gpalvl2),'~') = nvl(to_char(c_gpaLvl2),'~')
        and nvl(to_char(szbsyms_gpalvl3),'~') = nvl(to_char(c_gpaLvl3),'~')
        and nvl(to_char(szbsyms_gpalvl4),'~') = nvl(to_char(c_gpaLvl4),'~')
        and nvl(szbsyms_fundsource,'~') = nvl(c_fundSrc,'~')
		and nvl(szbsyms_externalemail,'~') = nvl(c_externalemail,'~'); --RFC 561753 - NTOURNEY - 21-FEB-2023

    getSameAppRec_rec       getSameAppRec_c%rowtype;
    
    
    cursor getSameAppsRec2_c(c_stuPidm number, c_appTermCode varchar2, c_appNum number, c_appLvlCode varchar2, c_appSTypCode varchar2, c_appResd varchar2, c_appFPTime varchar2, 
                                c_appDecision varchar2, c_appDecDate date, c_applDate date, c_campus varchar2, c_collegeCode varchar2, c_degreeCode varchar2, c_majorCode  varchar2, 
                                c_programCode varchar2, c_deptDesc varchar2, c_majorConcDesc varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_appterm2,'~') = nvl(c_appTermCode,'~') 
        and nvl(to_char(szbsyms_appnum2),'~') = nvl(to_char(c_appNum),'~') 
        and nvl(szbsyms_applvlcode2,'~') = nvl(c_appLvlCode,'~') 
        and nvl(szbsyms_appstypcode2,'~') = nvl(c_appSTypCode,'~') 
        and nvl(szbsyms_appresd2,'~') = nvl(c_appResd,'~') 
        and nvl(szbsyms_appfptime2,'~') = nvl(c_appFPTime,'~') 
        and nvl(szbsyms_appdecision2,'~') = nvl(c_appDecision,'~') 
        and to_date(nvl(to_char(szbsyms_appdecdate2,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_appDecDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsyms_appldate2,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_applDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_appcampus2,'~') = nvl(c_campus,'~') 
        and nvl(szbsyms_appcollcode2,'~') = nvl(c_collegeCode,'~') 
        and nvl(szbsyms_appdegcode2,'~') = nvl(c_degreeCode,'~') 
        and nvl(szbsyms_appmajcode2,'~') = nvl(c_majorCode,'~') 
        and nvl(szbsyms_apppgmcode2,'~') = nvl(c_programCode,'~')
        and nvl(szbsyms_appdeptcode2,'~') = nvl(c_deptDesc,'~')
        and nvl(szbsyms_appmajorconccode2,'~') = nvl(c_majorConcDesc,'~')
        ;
        
    getSameAppsRec2_rec       getSameAppsRec2_c%rowtype;
    
    
    cursor getSameAppsRec3_c(c_stuPidm number, c_appTermCode varchar2, c_appNum number, c_appLvlCode varchar2, c_appSTypCode varchar2, c_appResd varchar2, c_appFPTime varchar2, 
                                c_appDecision varchar2, c_appDecDate date, c_applDate date, c_campus varchar2, c_collegeCode varchar2, c_degreeCode varchar2, c_majorCode  varchar2, 
                                c_programCode varchar2, c_deptDesc varchar2, c_majorConcDesc varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_appterm3,'~') = nvl(c_appTermCode,'~') 
        and nvl(to_char(szbsyms_appnum3),'~') = nvl(to_char(c_appNum),'~') 
        and nvl(szbsyms_applvlcode3,'~') = nvl(c_appLvlCode,'~') 
        and nvl(szbsyms_appstypcode3,'~') = nvl(c_appSTypCode,'~') 
        and nvl(szbsyms_appresd3,'~') = nvl(c_appResd,'~') 
        and nvl(szbsyms_appfptime3,'~') = nvl(c_appFPTime,'~') 
        and nvl(szbsyms_appdecision3,'~') = nvl(c_appDecision,'~') 
        and to_date(nvl(to_char(szbsyms_appdecdate3,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_appDecDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsyms_appldate3,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_applDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_appcampus3,'~') = nvl(c_campus,'~') 
        and nvl(szbsyms_appcollcode3,'~') = nvl(c_collegeCode,'~') 
        and nvl(szbsyms_appdegcode3,'~') = nvl(c_degreeCode,'~') 
        and nvl(szbsyms_appmajcode3,'~') = nvl(c_majorCode,'~') 
        and nvl(szbsyms_apppgmcode3,'~') = nvl(c_programCode,'~')
        and nvl(szbsyms_appdeptcode3,'~') = nvl(c_deptDesc,'~')
        and nvl(szbsyms_appmajorconccode3,'~') = nvl(c_majorConcDesc,'~');
        
    getSameAppsRec3_rec       getSameAppsRec3_c%rowtype;          
    
    
    cursor getSameAppsRec4_c(c_stuPidm number, c_appTermCode varchar2, c_appNum number, c_appLvlCode varchar2, c_appSTypCode varchar2, c_appResd varchar2, c_appFPTime varchar2, 
                                c_appDecision varchar2, c_appDecDate date, c_applDate date, c_campus varchar2, c_collegeCode varchar2, c_degreeCode varchar2, c_majorCode  varchar2, 
                                c_programCode varchar2, c_deptDesc varchar2, c_majorConcDesc varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_appterm4,'~') = nvl(c_appTermCode,'~') 
        and nvl(to_char(szbsyms_appnum4),'~') = nvl(to_char(c_appNum),'~') 
        and nvl(szbsyms_applvlcode4,'~') = nvl(c_appLvlCode,'~') 
        and nvl(szbsyms_appstypcode4,'~') = nvl(c_appSTypCode,'~') 
        and nvl(szbsyms_appresd4,'~') = nvl(c_appResd,'~') 
        and nvl(szbsyms_appfptime4,'~') = nvl(c_appFPTime,'~') 
        and nvl(szbsyms_appdecision4,'~') = nvl(c_appDecision,'~') 
        and to_date(nvl(to_char(szbsyms_appdecdate4,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_appDecDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsyms_appldate4,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_applDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_appcampus4,'~') = nvl(c_campus,'~') 
        and nvl(szbsyms_appcollcode4,'~') = nvl(c_collegeCode,'~') 
        and nvl(szbsyms_appdegcode4,'~') = nvl(c_degreeCode,'~') 
        and nvl(szbsyms_appmajcode4,'~') = nvl(c_majorCode,'~') 
        and nvl(szbsyms_apppgmcode4,'~') = nvl(c_programCode,'~')
        and nvl(szbsyms_appdeptcode4,'~') = nvl(c_deptDesc,'~')
        and nvl(szbsyms_appmajorconccode4,'~') = nvl(c_majorConcDesc,'~');
        
    getSameAppsRec4_rec       getSameAppsRec4_c%rowtype;          
    
    
    cursor getSameAppsRec5_c(c_stuPidm number, c_appTermCode varchar2, c_appNum number, c_appLvlCode varchar2, c_appSTypCode varchar2, c_appResd varchar2, c_appFPTime varchar2, 
                                c_appDecision varchar2, c_appDecDate date, c_applDate date, c_campus varchar2, c_collegeCode varchar2, c_degreeCode varchar2, c_majorCode  varchar2, 
                                c_programCode varchar2, c_deptDesc varchar2, c_majorConcDesc varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_appterm5,'~') = nvl(c_appTermCode,'~') 
        and nvl(to_char(szbsyms_appnum5),'~') = nvl(to_char(c_appNum),'~') 
        and nvl(szbsyms_applvlcode5,'~') = nvl(c_appLvlCode,'~') 
        and nvl(szbsyms_appstypcode5,'~') = nvl(c_appSTypCode,'~') 
        and nvl(szbsyms_appresd5,'~') = nvl(c_appResd,'~') 
        and nvl(szbsyms_appfptime5,'~') = nvl(c_appFPTime,'~') 
        and nvl(szbsyms_appdecision5,'~') = nvl(c_appDecision,'~') 
        and to_date(nvl(to_char(szbsyms_appdecdate5,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_appDecDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsyms_appldate5,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_applDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_appcampus5,'~') = nvl(c_campus,'~') 
        and nvl(szbsyms_appcollcode5,'~') = nvl(c_collegeCode,'~') 
        and nvl(szbsyms_appdegcode5,'~') = nvl(c_degreeCode,'~') 
        and nvl(szbsyms_appmajcode5,'~') = nvl(c_majorCode,'~') 
        and nvl(szbsyms_apppgmcode5,'~') = nvl(c_programCode,'~')
        and nvl(szbsyms_appdeptcode5,'~') = nvl(c_deptDesc,'~')
        and nvl(szbsyms_appmajorconccode5,'~') = nvl(c_majorConcDesc,'~')
        ;
        
    getSameAppsRec5_rec       getSameAppsRec5_c%rowtype;
    
    
    cursor getSameRegRec_c(c_stuPidm number, c_userName varchar2, c_studentID varchar2, c_fName varchar2, c_lName varchar2, c_fullName varchar2, 
                            c_mName varchar2, c_prefName varchar2, c_email varchar2, c_phone varchar2, c_birthDate date, c_gender varchar2, c_pronoun varchar2, 
                            c_ethnicity varchar2, c_citzDesc varchar2, c_permStreetLine1 varchar2, c_permStreetLine2 varchar2,  c_permStreetLine3 varchar2,  c_permCity varchar2, c_permProv varchar2,  
                            c_permPostCode varchar2,  c_permCountry varchar2,  c_currStreetLine1 varchar2,  c_currStreetLine2 varchar2, c_currStreetLine3 varchar2,
                            c_currCity varchar2, c_currProv varchar2,  c_currPostCode varchar2,  c_currCountry varchar2, c_emrContactFName varchar2, 
                            c_emrContactLName varchar2, c_emrContactReltn varchar2, c_emrContactPhone varchar2, c_disabilityStatus varchar2, c_recordType varchar2,
                            c_regTermCode varchar2, c_regLvlCode varchar2, c_regSTypCode varchar2, c_regResd varchar2, c_regFPTime varchar2, 
                            c_regCampus varchar2, c_regCollegeCode varchar2, c_regDegreeCode varchar2, c_regMajorCode varchar2, c_regProgramCode varchar2, 
                            c_regDeptDesc varchar2, c_regMajorConcDesc varchar2, c_lastTermEnrolled varchar2, c_gpaLvl1 number, c_gpaLvl2 number, c_gpaLvl3 number, 
                            c_gpaLvl4 number, c_fundSrc varchar2, c_externalEmail varchar2) is
        
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_username,'~') = nvl(c_userName,'~')
        and nvl(szbsyms_studentID,'~') = nvl(c_studentID,'~')
        and nvl(szbsyms_firstname,'~') = nvl(c_fName,'~') 
        and nvl(szbsyms_lastname,'~') = nvl(c_lName,'~')
        and nvl(szbsyms_fullname,'~') = nvl(c_fullName,'~')        
        and nvl(szbsyms_middlename,'~') = nvl(c_mName,'~')
        and nvl(szbsyms_prefname,'~') = nvl(c_prefName,'~')       
        and nvl(szbsyms_email,'~') = nvl(c_email,'~')
        and nvl(szbsyms_phone,'~') = nvl(c_phone,'~')
        and to_date(nvl(to_char(szbsyms_birthdate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_birthDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsyms_gender,'~') = nvl(c_gender,'~')
        and nvl(szbsyms_pronoun,'~') = nvl(c_pronoun,'~')
        and nvl(szbsyms_ethnicity,'~') = nvl(c_ethnicity,'~')
        and nvl(szbsyms_citizenship,'~') = nvl(c_citzDesc,'~')
        and nvl(szbsyms_permstreetline1,'~') = nvl(c_permStreetLine1,'~')
        and nvl(szbsyms_permstreetline2,'~') = nvl(c_permStreetLine2,'~')
        and nvl(szbsyms_permstreetline3,'~') = nvl(c_permStreetLine3,'~')
        and nvl(szbsyms_permcity,'~') = nvl(c_permCity,'~')
        and nvl(szbsyms_permprov,'~') = nvl(c_permProv,'~') 
        and nvl(szbsyms_permpostcode,'~') = nvl(c_permPostCode,'~') 
        and nvl(szbsyms_permcountry,'~') = nvl(c_permCountry,'~') 
        and nvl(szbsyms_currstreetline1,'~') = nvl(c_currStreetLine1,'~') 
        and nvl(szbsyms_currstreetline2,'~') = nvl(c_currStreetLine2,'~') 
        and nvl(szbsyms_currstreetline3,'~') = nvl(c_currStreetLine3,'~') 
        and nvl(szbsyms_currcity,'~') = nvl(c_currCity,'~') 
        and nvl(szbsyms_currprov,'~') = nvl(c_currProv,'~') 
        and nvl(szbsyms_currpostcode,'~') = nvl(c_currPostCode,'~') 
        and nvl(szbsyms_currcountry,'~') = nvl(c_currCountry,'~') 
        and nvl(szbsyms_emrcontfname,'~') = nvl(c_emrContactFName,'~') 
        and nvl(szbsyms_emrcontlname,'~') = nvl(c_emrContactLName,'~') 
        and nvl(szbsyms_emrcontreltn,'~') = nvl(c_emrContactReltn,'~') 
        and nvl(szbsyms_emrcontphone,'~') = nvl(c_emrContactPhone,'~') 
        and nvl(szbsyms_disability,'~') = nvl(c_disabilityStatus,'~') 
--        and nvl(szbsyms_rectype,'~') = nvl(c_recordType,'~') 
        and nvl(szbsyms_regterm,'~') = nvl(c_regTermCode,'~') 
        and nvl(szbsyms_reglvlcode,'~') = nvl(c_regLvlCode,'~') 
        and nvl(szbsyms_regstypcode,'~') = nvl(c_regSTypCode,'~') 
        and nvl(szbsyms_regresd,'~') = nvl(c_regResd,'~') 
        and nvl(szbsyms_regfptime,'~') = nvl(c_regFPTime,'~') 
        and nvl(szbsyms_regcampus,'~') = nvl(c_regCampus,'~') 
        and nvl(szbsyms_regcollege,'~') = nvl(c_regCollegeCode,'~') 
        and nvl(szbsyms_regdegree,'~') = nvl(c_regDegreeCode,'~') 
        and nvl(szbsyms_regmajor,'~') = nvl(c_regMajorCode,'~') 
        and nvl(szbsyms_regprogram,'~') = nvl(c_regProgramCode,'~') 
        and nvl(szbsyms_regdeptcode,'~') = nvl(c_regdeptdesc,'~')
        and nvl(szbsyms_regmajorconccode,'~') = nvl(c_regmajorconcdesc,'~')
        and nvl(szbsyms_lasttermenrolled,'~') = nvl(c_lastTermEnrolled,'~')
        and nvl(to_char(szbsyms_gpalvl1),'~') = nvl(to_char(c_gpaLvl1),'~')
        and nvl(to_char(szbsyms_gpalvl2),'~') = nvl(to_char(c_gpaLvl2),'~')
        and nvl(to_char(szbsyms_gpalvl3),'~') = nvl(to_char(c_gpaLvl3),'~')
        and nvl(to_char(szbsyms_gpalvl4),'~') = nvl(to_char(c_gpaLvl4),'~')
        and nvl(szbsyms_fundsource,'~') = nvl(c_fundSrc,'~')
		and nvl(szbsyms_externalemail,'~') = nvl(c_externalemail,'~'); --RFC 561753 - NTOURNEY - 21-FEB-2023

    getSameRegRec_rec       getSameRegRec_c%rowtype; 
    
    
    cursor getSameRegsRec_c(c_stuPidm number, c_regTermCode varchar2, c_regLvlCode varchar2, c_regSTypCode varchar2,
                            c_regResd varchar2, c_regFPTime varchar2, c_regCampus varchar2, c_regCollegeCode varchar2, c_regDegreeCode varchar2, 
                            c_regMajorCode varchar2, c_regProgramCode varchar2) is
                            
        select 'S' inSZBSYMSSame
        from szbsyms
        where nvl(to_char(szbsyms_pidm),'~') = nvl(to_char(c_stuPidm),'~')
        and nvl(szbsyms_regterm,'~') = nvl(c_regTermCode,'~') 
        and nvl(szbsyms_reglvlcode,'~') = nvl(c_regLvlCode,'~') 
        and nvl(szbsyms_regstypcode,'~') = nvl(c_regSTypCode,'~') 
        and nvl(szbsyms_regresd,'~') = nvl(c_regResd,'~') 
        and nvl(szbsyms_regfptime,'~') = nvl(c_regFPTime,'~') 
        and nvl(szbsyms_regcampus,'~') = nvl(c_regCampus,'~') 
        and nvl(szbsyms_regcollege,'~') = nvl(c_regCollegeCode,'~') 
        and nvl(szbsyms_regdegree,'~') = nvl(c_regDegreeCode,'~') 
        and nvl(szbsyms_regmajor,'~') = nvl(c_regMajorCode,'~') 
        and nvl(szbsyms_regprogram,'~') = nvl(c_regProgramCode,'~');
        --and nvl(szbsyms_phone,'~') = nvl(fullPhone,'~'); --Nigel commented    -- Added April 2024 GM We may need to add more to this Cursor (as above) to capture more field differences         
    
    getSameRegsRec_rec       getSameRegsRec_c%rowtype; 

    
    cursor getStudentDetails_c(c_pidm number) is 
        
        select spriden_id,
               spriden_first_name,
               spriden_last_name,
               spriden_mi
        from SPRIDEN where spriden_pidm = c_pidm
        and spriden_change_ind is null;  --Added 10 SEP 2021 to resolve issue with old last names. - PL
    
    getStudentDetails_rec    getStudentDetails_c%rowtype;
    
    
    cursor getStuPersDetails_c(c_pidm number) is 
        
        select spbpers_birth_date,
               spbpers_pref_first_name,
               spbpers_sex,
               spbpers_pprn_code,
               spbpers_ethn_code,
               spbpers_citz_code
        from SPBPERS where spbpers_pidm = c_pidm;
    
    getStuPersDetails_rec    getStuPersDetails_c%rowtype;
    
    
    cursor getUpdate_c(c_stuPidm number) is
        
        select 'U' inSZBSYMSUpdate
        from szbsyms
        where szbsyms_pidm = c_stuPidm;
        
    getUpdate_rec       getUpdate_c%rowtype;
    
    
    cursor getUpdateSZR_c(c_stuPidm number) is
        
        select 'U' inSZRSYMSUpdate
        from szrsyms
        where szrsyms_pidm = c_stuPidm
        and szrsyms_szradddate = (select max(szrsyms_szradddate) from szrsyms
                                  where szrsyms_pidm = c_stuPidm)
        and szrsyms_szradddate > sysdate - 1/48;
       
    getUpdateSZR_rec       getUpdateSZR_c%rowtype;
    
    
    
    procedure getCampus_p(p_campCode varchar2, p_pidm number) is
    
    BEGIN
        campus := null;
        
        if p_campCode is not null then
            select stvcamp_desc into campus
            from stvcamp where stvcamp_code = p_campCode;
        
        end if;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getCampus_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getCampus_p;
    
    
    procedure getCollege_p(p_collCode varchar2, p_pidm number) is
    
    BEGIN
        collegeCode := null;
        
        select stvcoll_desc
        into collegeCode
        from stvcoll
        where stvcoll_code = p_collCode
        and p_collCode is not null; --15-JAN-2024 NTOURNEY added condition to limit errors
        
       
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getCollege_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' coll: ' || p_collcode ||' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            --insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date)  values (subjct, msg, sysdate); 
    
    END getCollege_p;
    
    
    procedure getCurrAddr_p(p_pidm number) is
    
    BEGIN
        currStreetLine1 := null;
        currStreetLine2 := null;
        currStreetLine3 := null;
        currCity := null;
        currProv := null;
        currPostCode := null;
        currCtryCode := null;
        currCountry := null;
        getCurrAddr_rec := null;
        
        open getCurrAddr_c(p_pidm);
        fetch getCurrAddr_c into getCurrAddr_rec;
        
        currStreetLine1 := getCurrAddr_rec.spraddr_street_line1;
        currStreetLine2 := getCurrAddr_rec.spraddr_street_line2;
        currStreetLine3 := getCurrAddr_rec.spraddr_street_line3;
        currCity := getCurrAddr_rec.spraddr_city;
        currProv := getCurrAddr_rec.spraddr_stat_code;
        currPostCode := getCurrAddr_rec.spraddr_zip;
        currCtryCode := getCurrAddr_rec.spraddr_natn_code;
        
        close getCurrAddr_c;
        
        if currCtryCode is not null then
            select stvnatn_nation into currCountry
            from stvnatn where stvnatn_code = currCtryCode;
            
        end if;
        
    
    EXCEPTION
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getCurrAddr_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
            
    END getCurrAddr_p;
    
    
    procedure getDegree_p(p_degCode varchar2, p_pidm number) is
    
    BEGIN
        degreeCode := null;
        
        select stvdegc_desc into degreeCode
        from stvdegc where stvdegc_code = p_degCode;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getDegree_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getDegree_p;
    
    
    procedure getDisability_p(p_pidm number) is
    
    BEGIN
        disabilityStatus := null;
--        disabledCount := 0;
        
--        select count(*) into disabledCount
--        from sprmedi
--        where sprmedi_pidm = p_pidm;
        
--        if disabledCount >= 1 then
            select DECODE(max(sprmedi_medi_code),'01','Self-identified as Disabled',
                                                 '02','Disability Verified Internally',
                                                 '03','Disability Verified by SFA',
                                                 'DISABSURV','Disability Survey') sprmedi_medi_code
            into disabilityStatus
            from sprmedi
            where sprmedi_pidm = p_pidm;
--        end if;


    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getDisability_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN        
            subjct := 'symplicityStudentDataLoad.getDisability_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
            
    END getDisability_p;
    
    
    procedure getFundSrc_p(p_termCode varchar2, p_pidm number) is
    
    BEGIN
        fundSrcCode := null;
        fundSrcDesc := null;
    
        select max(sgrsatt_atts_code) into fundSrcCode 
        from sgrsatt where sgrsatt_pidm = p_pidm
        and sgrsatt_term_code_eff = p_termCode
        and sgrsatt_atts_code in ('C26','CEIC','CRTP','DTIN','DTIS','INT','NSIM',
            'NCC','OTHR','PD1','PD3','PTWY','RFP','RES','SSDP','SSM','SSP','SPON',
            'VRDP','WCB','CIC','INAC','PTA','PTAS','PTAM','PTAN','PTAD','PTAF','PYA',
            'PTAL','LINK','PYAL','HRDC','EAPD','CES','BAND','BRDG','CGR','METI','MULT',
            'SS','IRSS')
        and sgrsatt_atts_code is not null;
        
        if fundSrcCode is not null then
            select stvatts_desc into fundSrcDesc
            from stvatts where stvatts_code = fundSrcCode;
        
        end if;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getFundSrc_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN        
            subjct := 'symplicityStudentDataLoad.getFundSrc_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
    
    END getFundSrc_p;
    
    
    procedure getEmrContact_p(p_pidm number) is
    
    BEGIN
        emrContactFName := null;  --spremrg
        emrContactLName := null;
        emrContactReltn := null;
        emrContactPhone := null;
        getEmrContact_rec := null;
        
        open getEmrContact_c(p_pidm);
        fetch getEmrContact_c into getEmrContact_rec;
        
        emrContactFName := getEmrContact_rec.spremrg_first_name;  --spremrg
        emrContactLName := getEmrContact_rec.spremrg_last_name;
        emrContactReltn := getEmrContact_rec.spremrg_relt_code;
        emrContactPhone := getEmrContact_rec.spremrg_phone_area || getEmrContact_rec.spremrg_phone_number;
        
        close getEmrContact_c;
    

    EXCEPTION
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getEmrContact_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
    
    END getEmrContact_p;
    
    
    procedure getGPA_p(p_pidm number) is
    
    BEGIN
        gpaLvl1 := null;
        gpaLvl2 := null;
        gpaLvl3 := null;
        gpaLvl4 := null;
--        gpa1Cnt := 0;
--        gpa2Cnt := 0;
--        gpa3Cnt := 0;
--        gpa4Cnt := 0;
        
--        select count(*) into gpa1Cnt
--        from shrlgpa where shrlgpa_pidm = p_pidm
--        and shrlgpa_levl_code = 01
--        and shrlgpa_gpa_type_ind = 'O';
        
--        if gpa1Cnt > 0 then
            select max(shrlgpa_gpa) into gpaLvl1
            from shrlgpa where shrlgpa_pidm = p_pidm
            and shrlgpa_levl_code = 01
            and shrlgpa_gpa_type_ind = 'O';
--        end if;
        
--        select count(*) into gpa2Cnt
--        from shrlgpa where shrlgpa_pidm = p_pidm
--        and shrlgpa_levl_code = 02
--        and shrlgpa_gpa_type_ind = 'O';
        
--        if gpa2Cnt > 0 then
            select max(shrlgpa_gpa) into gpaLvl2
            from shrlgpa where shrlgpa_pidm = p_pidm
            and shrlgpa_levl_code = 02
            and shrlgpa_gpa_type_ind = 'O';
--        end if;
        
--        select count(*) into gpa3Cnt
--        from shrlgpa where shrlgpa_pidm = p_pidm
--        and shrlgpa_levl_code = 03
--        and shrlgpa_gpa_type_ind = 'O';
        
--        if gpa3Cnt > 0 then
            select max(shrlgpa_gpa) into gpaLvl3
            from shrlgpa where shrlgpa_pidm = p_pidm
            and shrlgpa_levl_code = 03
            and shrlgpa_gpa_type_ind = 'O';
--        end if;
        
--        select count(*) into gpa4Cnt
--        from shrlgpa where shrlgpa_pidm = p_pidm
--        and shrlgpa_levl_code = 04
--        and shrlgpa_gpa_type_ind = 'O';
        
--        if gpa4Cnt > 0 then
            select max(shrlgpa_gpa) into gpaLvl4
            from shrlgpa where shrlgpa_pidm = p_pidm
            and shrlgpa_levl_code = 04
            and shrlgpa_gpa_type_ind = 'O';
--        end if;
       
 
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getGPA_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN        
            subjct := 'symplicityStudentDataLoad.getGPA_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate);     
            Commit;

    END getGPA_p;
    
    
    procedure getLastTermEnrolled_p(p_stuPidm number) is
    
    BEGIN   
        lastTermEnrolled := null;
        
        --select max(szvestu_etrm_code) into lastTermEnrolled from szvestu 
        --where szvestu_pidm = p_stuPidm;
        
        --NTOURNEY RFC562440 01-OCT-2024
        --Modified to rank the terms based on programs taking priority over non-program
        --Should rank regular terms over con-ed, for example.
        SELECT szvestu_etrm_code
          INTO lastTermEnrolled
          FROM (  SELECT szvestu_etrm_code,
                         CASE WHEN szvestu_program_1 != 'NONPRGM' THEN TO_NUMBER (szvestu_etrm_code) + 20 ELSE TO_NUMBER (szvestu_etrm_code) END    AS etrm_sort_priority
                    FROM szvestu
                   WHERE szvestu_pidm = p_stuPidm
                ORDER BY 2 DESC)
         WHERE ROWNUM = 1;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getLastTermEnrolled_p Exception - No Data Found';
            msg := 'PIDM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN        
            subjct := 'symplicityStudentDataLoad.getLastTermEnrolled_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate);     
         Commit;

    END getLastTermEnrolled_p;
    
    
    procedure getMajor_p(p_majCode varchar2, p_pidm number) is
    
    BEGIN
        majorCode := null;
        
        select stvmajr_desc into majorCode
        from stvmajr where stvmajr_code = p_majCode;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getMajor_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getMajor_p;
    
    
	procedure getDepartament_p(p_deptCode varchar2, p_pidm number) is
    
    BEGIN
        deptDesc := null;
        
        IF p_deptCode IS NULL THEN
            RETURN;
        END IF;
        
        select STVDEPT_DESC 
		  into deptDesc
          from STVDEPT 
		 where STVDEPT_CODE = p_deptCode;        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getDepartament_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getDepartament_p;
	
	procedure getMajorConcentration_p(p_majConcentrationCode varchar2, p_pidm number) is
    
    BEGIN
        majorConcDesc := null;
        
        IF p_majConcentrationCode IS NULL THEN
            RETURN;
        END IF;
        
        select stvmajr_desc 
		  into majorConcDesc
          from stvmajr 
		 where stvmajr_code = p_majConcentrationCode;        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getMajorConcentration_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getMajorConcentration_p;
	
    procedure getPermAddr_p(p_pidm number) is
    
    BEGIN
        permStreetLine1 := null;
        permStreetLine2 := null;
        permStreetLine3 := null;
        permCity := null;
        permProv := null;
        permPostCode := null;
        permCtryCode := null;
        permCountry := null;
        getPermAddr_rec := null;
        
        open getPermAddr_c(p_pidm);
        fetch getPermAddr_c into getPermAddr_rec;
        
        permStreetLine1 := getPermAddr_rec.spraddr_street_line1;
        permStreetLine2 := getPermAddr_rec.spraddr_street_line2;
        permStreetLine3 := getPermAddr_rec.spraddr_street_line3;
        permCity := getPermAddr_rec.spraddr_city;
        permProv := getPermAddr_rec.spraddr_stat_code;
        permPostCode := getPermAddr_rec.spraddr_zip;
        permCtryCode := getPermAddr_rec.spraddr_natn_code;
        
        close getPermAddr_c;
        
        if permCtryCode is not null then
            select stvnatn_nation into permCountry
            from stvnatn where stvnatn_code = permCtryCode;
        
        end if;
        
    
    EXCEPTION
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getPermAddr_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
    
    END getPermAddr_p;
    
    
    procedure getSameAppRec_p(p_stuPidm number, p_userName varchar2, p_studentID varchar2, p_fName varchar2, p_lName varchar2, p_fullName varchar2, 
        p_mName varchar2, p_prefName varchar2, p_email varchar2, p_phone varchar2, p_birthDate date, p_gender varchar2, p_pronoun varchar2, 
        p_ethnicity varchar2, p_citzDesc varchar2, p_permStreetLine1 varchar2, p_permStreetLine2 varchar2,  p_permStreetLine3 varchar2,  p_permCity varchar2, p_permProv varchar2,  
        p_permPostCode varchar2,  p_permCountry varchar2,  p_currStreetLine1 varchar2,  p_currStreetLine2 varchar2, p_currStreetLine3 varchar2,
        p_currCity varchar2, p_currProv varchar2,  p_currPostCode varchar2,  p_currCountry varchar2, p_emrContactFName varchar2, 
        p_emrContactLName varchar2, p_emrContactReltn varchar2, p_emrContactPhone varchar2, p_disabilityStatus varchar2, p_recordType varchar2,
        p_appTermCode varchar2, p_appNum  varchar2, p_appLvlCode varchar2, p_appSTypCode varchar2, p_appResd varchar2, p_appFPTime varchar2, 
        p_appDecision varchar2, p_appDecDate date, p_applDate date, p_campus varchar2, p_collegeCode varchar2, p_degreeCode varchar2, p_majorCode  varchar2, 
        p_programCode varchar2, p_deptDesc varchar2, p_majorConcDesc varchar2, p_lastTermEnrolled varchar2, p_gpaLvl1 number, p_gpaLvl2 number, p_gpaLvl3 number, p_gpaLvl4 number, p_fundSrc varchar2, p_externalEmail varchar2) is
    
    BEGIN
        toInsertUpdate := 'Y'; 
        getSameAppRec_rec := null;

        open getSameAppRec_c(p_stuPidm, p_userName, p_studentID, p_fName, p_lName, p_fullName, p_mName, p_prefName, p_email,
                             p_phone, p_birthDate, p_gender, p_pronoun, p_ethnicity, p_citzDesc, p_permStreetLine1, p_permStreetLine2,
                             p_permStreetLine3, p_permCity, p_permProv, p_permPostCode,  p_permCountry,  p_currStreetLine1,  
                             p_currStreetLine2, p_currStreetLine3, p_currCity, p_currProv,  p_currPostCode, p_currCountry, p_emrContactFName, 
                             p_emrContactLName, p_emrContactReltn, p_emrContactPhone, p_disabilityStatus, p_recordType,
                             p_appTermCode, p_appNum , p_appLvlCode, p_appSTypCode, p_appResd, p_appFPTime, p_appDecision,
                             p_appDecDate, p_applDate, p_campus, p_collegeCode, p_degreeCode, p_majorCode, p_programCode, p_deptDesc, p_majorConcDesc,  
                             p_lastTermEnrolled, p_gpaLvl1, p_gpaLvl2, p_gpaLvl3, p_gpaLvl4, p_fundSrc, p_externalEmail);
        fetch getSameAppRec_c into getSameAppRec_rec;
        
        if getSameAppRec_rec.inSZBSYMSSame = 'S' then
            toInsertUpdate := 'N';
        
        end if;
        
        close getSameAppRec_c;
            
    END getSameAppRec_p;
    
    
    procedure getSameAppsRec_p(p_stuPidm number, p_appTermCode varchar2, p_appNum number, p_appLvlCode varchar2, p_appSTypCode varchar2, p_appResd varchar2, p_appFPTime varchar2, 
                                p_appDecision varchar2, p_appDecDate date, p_applDate date, p_campus varchar2, p_collegeCode varchar2, p_degreeCode varchar2, p_majorCode  varchar2, 
                                p_programCode varchar2, p_deptDesc varchar2, p_majorConcDesc varchar2, p_rowCount number) is
    
    BEGIN
        toInsertUpdate := 'Y'; 
        getSameAppsRec2_rec := null;
        getSameAppsRec3_rec := null;
        getSameAppsRec4_rec := null;
        getSameAppsRec5_rec := null;
                
        if p_rowCount = 2 then        
            open getSameAppsRec2_c(p_stuPidm, p_appTermCode, p_appNum , p_appLvlCode, p_appSTypCode, p_appResd, p_appFPTime, p_appDecision,
                                 p_appDecDate, p_applDate, p_campus, p_collegeCode, p_degreeCode, p_majorCode, p_programCode, p_deptDesc, p_majorConcDesc);
            fetch getSameAppsRec2_c into getSameAppsRec2_rec;
        
            if getSameAppsRec2_rec.inSZBSYMSSame = 'S' then
                toInsertUpdate := 'N';
            
            end if;
            
            close getSameAppsRec2_c;
        
        elsif p_rowCount = 3 then
            open getSameAppsRec3_c(p_stuPidm, p_appTermCode, p_appNum , p_appLvlCode, p_appSTypCode, p_appResd, p_appFPTime, p_appDecision,
                                 p_appDecDate, p_applDate, p_campus, p_collegeCode, p_degreeCode, p_majorCode, p_programCode, p_deptDesc, p_majorConcDesc);
            fetch getSameAppsRec3_c into getSameAppsRec3_rec;
        
            if getSameAppsRec3_rec.inSZBSYMSSame = 'S' then
                toInsertUpdate := 'N';
            
            end if;
            
            close getSameAppsRec3_c;
        
        elsif p_rowCount = 4 then
            open getSameAppsRec4_c(p_stuPidm, p_appTermCode, p_appNum , p_appLvlCode, p_appSTypCode, p_appResd, p_appFPTime, p_appDecision,
                                 p_appDecDate, p_applDate, p_campus, p_collegeCode, p_degreeCode, p_majorCode, p_programCode, p_deptDesc, p_majorConcDesc);
            fetch getSameAppsRec4_c into getSameAppsRec4_rec;
        
            if getSameAppsRec4_rec.inSZBSYMSSame = 'S' then
                toInsertUpdate := 'N';
            
            end if;
            
            close getSameAppsRec4_c;
            
        elsif p_rowCount = 5 then
            open getSameAppsRec5_c(p_stuPidm, p_appTermCode, p_appNum , p_appLvlCode, p_appSTypCode, p_appResd, p_appFPTime, p_appDecision,
                                 p_appDecDate, p_applDate, p_campus, p_collegeCode, p_degreeCode, p_majorCode, p_programCode, p_deptDesc, p_majorConcDesc);
            fetch getSameAppsRec5_c into getSameAppsRec5_rec;
        
            if getSameAppsRec5_rec.inSZBSYMSSame = 'S' then
                toInsertUpdate := 'N';
            
            end if;
            
            close getSameAppsRec5_c;
        
        end if;

    END getSameAppsRec_p;
    
    
    procedure getSameRegRec_p(p_stuPidm number, p_userName varchar2, p_studentID varchar2, p_fName varchar2, p_lName varchar2, p_fullName varchar2, 
        p_mName varchar2, p_prefName varchar2, p_email varchar2, p_phone varchar2, p_birthDate date, p_gender varchar2, p_pronoun varchar2, 
        p_ethnicity varchar2, p_citzDesc varchar2, p_permStreetLine1 varchar2, p_permStreetLine2 varchar2,  p_permStreetLine3 varchar2,  p_permCity varchar2, p_permProv varchar2,  
        p_permPostCode varchar2,  p_permCountry varchar2,  p_currStreetLine1 varchar2,  p_currStreetLine2 varchar2, p_currStreetLine3 varchar2,
        p_currCity varchar2, p_currProv varchar2,  p_currPostCode varchar2,  p_currCountry varchar2, p_emrContactFName varchar2, 
        p_emrContactLName varchar2, p_emrContactReltn varchar2, p_emrContactPhone varchar2, p_disabilityStatus varchar2, p_recordType varchar2,
        p_regTermCode varchar2, p_regLvlCode varchar2, p_regSTypCode varchar2, p_regResd varchar2, p_regFPTime varchar2, 
        p_regCampus varchar2, p_regCollegeCode varchar2, p_regDegreeCode varchar2, p_regMajorCode varchar2, p_regProgramCode varchar2, p_deptDesc varchar2, p_majorConcDesc varchar2,
        p_lastTermEnrolled varchar2, p_gpaLvl1 number, p_gpaLvl2 number, p_gpaLvl3 number, p_gpaLvl4 number, p_fundSrc varchar2, p_externalEmail varchar2) is
    
    BEGIN
        toInsertUpdate := 'Y'; 
        getSameRegRec_rec := null;

        open getSameRegRec_c(p_stuPidm, p_userName, p_studentID, p_fName, p_lName, p_fullName, p_mName, p_prefName, p_email,
                             p_phone, p_birthDate, p_gender, p_pronoun, p_ethnicity, p_citzDesc, p_permStreetLine1, p_permStreetLine2,
                             p_permStreetLine3,  p_permCity, p_permProv, p_permPostCode,  p_permCountry,  p_currStreetLine1,  
                             p_currStreetLine2, p_currStreetLine3, p_currCity, p_currProv,  p_currPostCode,  p_currCountry, p_emrContactFName, 
                             p_emrContactLName, p_emrContactReltn, p_emrContactPhone, p_disabilityStatus, p_recordType,
                             p_regTermCode, p_regLvlCode, p_regSTypCode, p_regResd, p_regFPTime, p_regCampus, p_regCollegeCode,
                             p_regDegreeCode, p_regMajorCode, p_regProgramCode, p_deptDesc, p_majorConcDesc, 
                             p_lastTermEnrolled, p_gpaLvl1, p_gpaLvl2, p_gpaLvl3, p_gpaLvl4, p_fundSrc, p_externalEmail);
        fetch getSameRegRec_c into getSameRegRec_rec;
        
        if getSameRegRec_rec.inSZBSYMSSame = 'S' then
            toInsertUpdate := 'N';
        
        end if;
        
        close getSameRegRec_c;
            
    END getSameRegRec_p;
    
    
    procedure getSameRegsRec_p(p_stuPidm number, p_regTermCode varchar2, p_regLvlCode varchar2, p_regSTypCode varchar2,
                            p_regResd varchar2, p_regFPTime varchar2, p_regCampus varchar2, p_regCollegeCode varchar2, p_regDegreeCode varchar2, 
                            p_regMajorCode varchar2, p_regProgramCode varchar2) is
    
    BEGIN
        toInsertUpdate := 'Y'; 
        getSameRegsRec_rec := null;                        
        
        open getSameRegsRec_c(p_stuPidm, p_regTermCode, p_regLvlCode, p_regSTypCode, p_regResd, p_regFPTime, p_regCampus, p_regCollegeCode,
                             p_regDegreeCode, p_regMajorCode, p_regProgramCode);
        fetch getSameRegsRec_c into getSameRegsRec_rec;
        
        if getSameRegsRec_rec.inSZBSYMSSame = 'S' then
            toInsertUpdate := 'N';
        
        end if;
        
        close getSameRegsRec_c;
                         
    END getSameRegsRec_p;
    
    
    
    procedure getStudentDetails_p(p_pidm number) is
    
    BEGIN
        studentID := null;
        firstName := null;
        lastName := null;
        fullName := null;
        middleName := null;
        getStudentDetails_rec := null;
        
        open getStudentDetails_c(p_pidm);
        fetch getStudentDetails_c into getStudentDetails_rec;
        
        studentID := getStudentDetails_rec.spriden_id;
        firstName := getStudentDetails_rec.spriden_first_name;
        lastName := getStudentDetails_rec.spriden_last_name;
        --fullName := firstName || ' ' || lastName; It was moved to getStuPersDetails_p because will use prefered name. Ticket_ID 2155656
        middleName := getStudentDetails_rec.spriden_mi;
        
        close getStudentDetails_c;
    

    EXCEPTION
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getStudentDetails_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
    
    END getStudentDetails_p;
    
    
    procedure getStuPersDetails_p(p_pidm number) is
    BEGIN
        prefName := null;
        birthDate := null;   
        gender := null;
        pronoun := null;
        ethnCode := null;
        ethnicity := null;
        citzCode := null;
        citzDesc := null;
        getStuPersDetails_rec := null;
        
        open getStuPersDetails_c(p_pidm);
        fetch getStuPersDetails_c into getStuPersDetails_rec;
        
        prefName := getStuPersDetails_rec.spbpers_pref_first_name;
		
		IF REGEXP_REPLACE(UPPER(prefName), '[^A-Z]', '') IN ('NA', 'NO', 'NONE')  THEN
            prefName := NULL;
        END IF; 
        
		if trim(prefName) is null then 
			fullName := firstName || ' ' || lastName;
		else
            fullName := prefName || ' ' || lastName;
		end if; 
				
        birthDate := to_date(to_char(getStuPersDetails_rec.spbpers_birth_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
        gender := getStuPersDetails_rec.spbpers_sex;
        pronoun := getStuPersDetails_rec.spbpers_pprn_code;
        ethnCode := getStuPersDetails_rec.spbpers_ethn_code;
        citzCode := getStuPersDetails_rec.spbpers_citz_code;
        
        close getStuPersDetails_c;
        
        if ethnCode is not null then
            select stvethn_desc into ethnicity
            from stvethn where stvethn_code = ethnCode;
        
        end if;
        
        if citzCode is not null then
            select stvcitz_desc into citzDesc
            from stvcitz where stvcitz_code = citzCode;
        
        end if;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getStuPersDetails_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getStuPersDetails_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;

    END getStuPersDetails_p;
    
    
    procedure getStudentContact_p(p_pidm number) is
    
    BEGIN
        stuEmail := null;
        phoneLength := null;
        fullPhone := null;
--        emailCnt := 0;
--        phoneCnt := 0;
        
--        select count(*) into emailCnt
--        from goremal where goremal_pidm = p_pidm
--        and goremal_emal_code = 'IA'
--        and goremal_status_ind = 'A';
        
--        if emailCnt > 0 then
            
			--RFC561946 NTOURNEY 20-JUL-2023 begin changes
			
			--select max(goremal_email_address) into stuEmail
            --from goremal where goremal_pidm = p_pidm
            --and goremal_emal_code = 'IA'
            --and goremal_status_ind = 'A';
			
			--always use the username@saskpolytech.ca for email, goremal IA type was missing or incorrect for some students
			select gobtpac_external_user || '@saskpolytech.ca'
			  into stuEmail
			  from GOBTPAC where gobtpac_pidm = p_pidm;
			
			--RFC561946 NTOURNEY 20-JUL-2023 end changes
        
--        end if;
        
--        select count(*) into phoneCnt
--        from sprtele where sprtele_pidm = p_pidm
--        and sprtele_tele_code = 'PR'
--        and sprtele_status_ind is null
--        and sprtele_seqno = 
--            (
--                select max(sprtele_seqno)
--                from sprtele where sprtele_pidm = p_pidm
--                and sprtele_tele_code = 'PR'
--                and sprtele_status_ind is null
--            );
            
--        if phoneCnt > 0 then
           select nvl( max(length(sprtele_phone_number)), 0) into phoneLength
            from sprtele where sprtele_pidm = p_pidm
            and sprtele_tele_code = 'PR'
            and sprtele_status_ind is null
            and sprtele_seqno = 
                (
                    select max(sprtele_seqno)
                    from sprtele where sprtele_pidm = p_pidm
                    and sprtele_tele_code = 'PR'
                    and sprtele_status_ind is null
                );
                
            if phoneLength >= 7 then           
                select nvl(max(sprtele_phone_area || sprtele_phone_number), 'N/A') into fullPhone
                from sprtele where sprtele_pidm = p_pidm
                and sprtele_tele_code = 'PR'
                and sprtele_status_ind is null
                and sprtele_seqno = 
                    (
                        select max(sprtele_seqno)
                        from sprtele where sprtele_pidm = p_pidm
                        and sprtele_tele_code = 'PR'
                        and sprtele_status_ind is null
                    );
            /**
                        START
                The change is to get the mobile number when the PR number is null.
                Emmanuel Onwukwe - 2024-04-02

            **/      
            elsIF phoneLength = 0 then 

                    select nvl( max(length(sprtele_phone_number)), 0) into phoneLength
                    from sprtele where sprtele_pidm = p_pidm
                    and sprtele_tele_code = 'MB'
                    and sprtele_status_ind is null
                    and sprtele_seqno = 
                        (
                            select max(sprtele_seqno)
                            from sprtele where sprtele_pidm = p_pidm
                            and sprtele_tele_code = 'MB'
                            and sprtele_status_ind is null
                        );

                    if phoneLength >= 7 then           
                    select nvl(max(sprtele_phone_area || sprtele_phone_number), 'N/A') into fullPhone
                    from sprtele where sprtele_pidm = p_pidm
                    and sprtele_tele_code = 'MB'
                    and sprtele_status_ind is null
                    and sprtele_seqno = 
                        (
                            select max(sprtele_seqno)
                            from sprtele where sprtele_pidm = p_pidm
                            and sprtele_tele_code = 'MB'
                            and sprtele_status_ind is null
                        );
                        
                    elsif phoneLength = 0 then fullPhone := 'N/A';
                        
                    else  
                    select nvl( max(sprtele_phone_area || sprtele_phone_number || sprtele_phone_ext), 'N/A') into fullPhone
                    from sprtele where sprtele_pidm = p_pidm
                    and sprtele_tele_code = 'MB'
                    and sprtele_status_ind is null
                    and sprtele_seqno = 
                        (
                            select max(sprtele_seqno)
                            from sprtele where sprtele_pidm = p_pidm
                            and sprtele_tele_code = 'MB'
                            and sprtele_status_ind is null
                        );
                     End if;

           /**
                        END
                The change is to get the mobile number when the PR number is null.
                Emmanuel Onwukwe - 2024-04-02

            **/ 

            else 
                select nvl( max(sprtele_phone_area || sprtele_phone_number || sprtele_phone_ext), 'N/A') into fullPhone
                from sprtele where sprtele_pidm = p_pidm
                and sprtele_tele_code = 'PR'
                and sprtele_status_ind is null
                and sprtele_seqno = 
                    (
                        select max(sprtele_seqno)
                        from sprtele where sprtele_pidm = p_pidm
                        and sprtele_tele_code = 'PR'
                        and sprtele_status_ind is null
                    );
                    
             
            end if;
        
--        end if;

		--RFC 561753 - NTOURNEY - 21-FEB-2023
		--Get the external email address for this person
		externalEmail := intserv.gzpkis.get_external_email_address(p_pidm);
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getStudentContact_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getStudentContact_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
        
        
    END getStudentContact_p;
    
    
    procedure getUpdate_p(p_stuPidm number) is
    
    BEGIN
        toUpdate := 'N';
        getUpdate_rec := null;
        
        open getUpdate_c(p_stuPidm);
        fetch getUpdate_c into getUpdate_rec;
        
        if getUpdate_rec.inSZBSYMSUpdate = 'U' then
            toUpdate := 'Y';
            
        end if;
        
        close getUpdate_c;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getUpdate_p Exception - No Data Found';
            msg := 'PIDM: ' || p_stuPidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getUpdate_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;


    END getUpdate_p;
    

    procedure getUpdateSZR_p(p_stuPidm number) is
    
    BEGIN
        toUpdateSZR := 'Y';
        getNewSZBApp_rec := null;
        getUpdateSZR_rec := null;
        
        open getNewSZBApp_c(p_stuPidm);
        fetch getNewSZBApp_c into getNewSZBApp_rec;
          
        open getUpdateSZR_c(p_stuPidm);
        fetch getUpdateSZR_c into getUpdateSZR_rec;
           
        if (getNewSZBApp_rec.newAppRec = 'NA' or getUpdateSZR_rec.inSZRSYMSUpdate = 'U') then 
            toUpdateSZR := 'N';
            
        end if;
        
        close getNewSZBApp_c;
        
        close getUpdateSZR_c;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getUpdateSZR_p Exception - No Data Found';
            msg := 'PIDM: ' || p_stuPidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getUpdateSZR_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;


    END getUpdateSZR_p;
    
    
    
    procedure getUserName_p (p_pidm number) is
    
    BEGIN
        userName := null;
        
        select gobtpac_external_user into userName
        from GOBTPAC where gobtpac_pidm = p_pidm;
        
        userName := userName || '@saskpolytech.ca';
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityStudentDataLoad.getUserName Exception';
            msg := 'PIDM: ' || p_pidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            Email.send_mail(frm_add, /*to_add,*/ cc_add, subjct, msg, l_status); 
        WHEN too_many_rows THEN
            subjct := 'symplicityStudentDataLoad.getUserName_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
    
    END getUserName_p;


    procedure insert_szbsyms_p(p_stuPidm number, p_userName varchar2, p_studentID varchar2, p_fName varchar2, p_lName varchar2, p_fullName varchar2, 
        p_mName varchar2, p_prefName varchar2, p_email varchar2, p_phone varchar2, p_birthDate date, p_gender varchar2, p_pronoun varchar2, 
        p_ethnicity varchar2, p_citzDesc varchar2, p_permStreetLine1 varchar2, p_permStreetLine2 varchar2,  p_permStreetLine3 varchar2,  p_permCity varchar2, p_permProv varchar2,  
        p_permPostCode varchar2,  p_permCountry varchar2,  p_currStreetLine1 varchar2,  p_currStreetLine2 varchar2, p_currStreetLine3 varchar2,
        p_currCity varchar2, p_currProv varchar2,  p_currPostCode varchar2,  p_currCountry varchar2, p_emrContactFName varchar2, 
        p_emrContactLName varchar2, p_emrContactReltn varchar2, p_emrContactPhone varchar2, p_disabilityStatus varchar2, p_recordType varchar2,
        p_appTermCode varchar2, p_appNum  varchar2, p_appLvlCode varchar2, p_appSTypCode varchar2, p_appResd varchar2, p_appFPTime varchar2, 
        p_appDecision varchar2, p_appDecDate date, p_applDate date, p_campus varchar2, p_collegeCode varchar2, p_degreeCode varchar2, p_majorCode  varchar2, 
        p_programCode varchar2, p_deptDesc varchar2, p_majorConcDesc varchar2, p_regTermCode varchar2, p_regLvlCode varchar2, p_regSTypCode varchar2, p_regResd varchar2, 
        p_regFPTime varchar2, p_regCampus varchar2, p_regCollegeCode varchar2, p_regDegreeCode varchar2, p_regMajorCode varchar2, p_regProgramCode varchar2, p_regDeptDesc varchar2, 
        p_regMajorConcDesc varchar2, p_lastTermEnrolled varchar2, p_gpaLvl1 number, p_gpaLvl2 number, p_gpaLvl3 number, p_gpaLvl4 number, p_fundSrc varchar2, p_externalEmail varchar2) is

    BEGIN
        INSERT INTO saturn.SZBSYMS
        (
            SZBSYMS_PIDM,
            SZBSYMS_USERNAME,        
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
            SZBSYMS_EMRCONTFNAME,
            SZBSYMS_EMRCONTLNAME,
            SZBSYMS_EMRCONTRELTN,
            SZBSYMS_EMRCONTPHONE,
            SZBSYMS_DISABILITY,
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
            SZBSYMS_ADDDATE,
            SZBSYMS_ACTIVITYDATE,
			SZBSYMS_EXTERNALEMAIL --RFC 561753 - NTOURNEY - 21-FEB-2023
--            SZBSYMS_
        )
        VALUES
        (
            p_stuPidm,
            p_userName,
            p_studentID,
            p_fName,
            p_lName,
            p_fullName,
            p_mName,
            p_prefName,
            p_email,
            p_phone,
            p_birthDate,
            p_gender,
            p_pronoun,
            p_ethnicity,
            p_citzDesc,
            p_permStreetLine1,
            p_permStreetLine2,
            p_permStreetLine3,
            p_permCity,
            p_permProv,  
            p_permPostCode,
            p_permCountry,
            p_currStreetLine1,
            p_currStreetLine2,
            p_currStreetLine3,
            p_currCity, 
            p_currProv,
            p_currPostCode,
            p_currCountry,
            p_emrContactFName,
            p_emrContactLName,
            p_emrContactReltn, 
            p_emrContactPhone,
            p_disabilityStatus,
            p_recordType,
            p_appTermCode,
            p_appNum,
            p_appLvlCode,
            p_appSTypCode,
            p_appResd,
            p_appFPTime,
            p_appDecision,
            p_appDecDate,
            p_applDate,
            p_campus,
            p_collegeCode,
            p_degreeCode,
            p_majorCode,
            p_programCode,
            p_deptDesc,
            p_majorConcDesc,
            p_regTermCode,
            p_regLvlCode,
            p_regSTypCode,
            p_regResd,
            p_regFPTime,
            p_regCampus, 
            p_regCollegeCode, 
            p_regDegreeCode, 
            p_regMajorCode,
            p_regProgramCode,
            p_regDeptDesc,
            p_regMajorConcDesc,
            p_lastTermEnrolled,
            p_gpaLvl1,
            p_gpaLvl2,
            p_gpaLvl3,
            p_gpaLvl4,
            p_fundSrc,
            sysdate,
            sysdate,
			p_externalEmail --RFC 561753 - NTOURNEY - 21-FEB-2023
        );
        
        COMMIT;
    
    END insert_szbsyms_p;
    
    procedure insert_szrsyms_p(p_stuPidm number) is
    
    BEGIN
        getExistingRec_rec := null;
        
        open getExistingRec_c(p_stuPidm);
        fetch getExistingRec_c into getExistingRec_rec;
        
        --getStudentContact_p(stuPidm); -- Added April 2024 GM
        
        INSERT INTO saturn.SZRSYMS
        (
            SZRSYMS_PIDM,
            SZRSYMS_USERNAME,
            SZRSYMS_STUDENTID,
            SZRSYMS_FIRSTNAME,
            SZRSYMS_LASTNAME,
            SZRSYMS_FULLNAME,
            SZRSYMS_MIDDLENAME,
            SZRSYMS_PREFNAME,
            SZRSYMS_EMAIL,
            SZRSYMS_PHONE,
            SZRSYMS_BIRTHDATE,
            SZRSYMS_GENDER,
            SZRSYMS_PRONOUN,
            SZRSYMS_ETHNICITY,
            SZRSYMS_CITIZENSHIP,
            SZRSYMS_PERMSTREETLINE1,
            SZRSYMS_PERMSTREETLINE2,
            SZRSYMS_PERMSTREETLINE3,
            SZRSYMS_PERMCITY,
            SZRSYMS_PERMPROV,
            SZRSYMS_PERMPOSTCODE,
            SZRSYMS_PERMCOUNTRY,
            SZRSYMS_CURRSTREETLINE1,
            SZRSYMS_CURRSTREETLINE2,
            SZRSYMS_CURRSTREETLINE3,
            SZRSYMS_CURRCITY,
            SZRSYMS_CURRPROV,
            SZRSYMS_CURRPOSTCODE,
            SZRSYMS_CURRCOUNTRY,
            SZRSYMS_DISABILITY,
            SZRSYMS_EMRCONTFNAME,
            SZRSYMS_EMRCONTLNAME,
            SZRSYMS_EMRCONTRELTN,
            SZRSYMS_EMRCONTPHONE,
            SZRSYMS_RECTYPE,
            SZRSYMS_APPTERM1,
            SZRSYMS_APPNUM1,
            SZRSYMS_APPLVLCODE1,
            SZRSYMS_APPSTYPCODE1,
            SZRSYMS_APPRESD1,
            SZRSYMS_APPFPTIME1,
            SZRSYMS_APPDECISION1,
            SZRSYMS_APPDECDATE1,
            SZRSYMS_APPLDATE1,
            SZRSYMS_APPCAMPUS1,
            SZRSYMS_APPCOLLCODE1,
            SZRSYMS_APPDEGCODE1,
            SZRSYMS_APPMAJCODE1,
            SZRSYMS_APPPGMCODE1,
            SZRSYMS_APPDEPTCODE1,
            SZRSYMS_APPMAJORCONCCODE1,
            SZRSYMS_APPTERM2,
            SZRSYMS_APPNUM2,
            SZRSYMS_APPLVLCODE2,
            SZRSYMS_APPSTYPCODE2,
            SZRSYMS_APPRESD2,
            SZRSYMS_APPFPTIME2,
            SZRSYMS_APPDECISION2,
            SZRSYMS_APPDECDATE2,
            SZRSYMS_APPLDATE2,
            SZRSYMS_APPCAMPUS2,
            SZRSYMS_APPCOLLCODE2,
            SZRSYMS_APPDEGCODE2,
            SZRSYMS_APPMAJCODE2,
            SZRSYMS_APPPGMCODE2,
            SZRSYMS_APPDEPTCODE2,
            SZRSYMS_APPMAJORCONCCODE2,
            SZRSYMS_APPTERM3,
            SZRSYMS_APPNUM3,
            SZRSYMS_APPLVLCODE3,
            SZRSYMS_APPSTYPCODE3,
            SZRSYMS_APPRESD3,
            SZRSYMS_APPFPTIME3,
            SZRSYMS_APPDECISION3,
            SZRSYMS_APPDECDATE3,
            SZRSYMS_APPLDATE3,
            SZRSYMS_APPCAMPUS3,
            SZRSYMS_APPCOLLCODE3,
            SZRSYMS_APPDEGCODE3,
            SZRSYMS_APPMAJCODE3,
            SZRSYMS_APPPGMCODE3,
            SZRSYMS_APPDEPTCODE3,
            SZRSYMS_APPMAJORCONCCODE3,
            SZRSYMS_APPTERM4,
            SZRSYMS_APPNUM4,
            SZRSYMS_APPLVLCODE4,
            SZRSYMS_APPSTYPCODE4,
            SZRSYMS_APPRESD4,
            SZRSYMS_APPFPTIME4,
            SZRSYMS_APPDECISION4,
            SZRSYMS_APPDECDATE4,
            SZRSYMS_APPLDATE4,
            SZRSYMS_APPCAMPUS4,
            SZRSYMS_APPCOLLCODE4,
            SZRSYMS_APPDEGCODE4,
            SZRSYMS_APPMAJCODE4,
            SZRSYMS_APPPGMCODE4,
            SZRSYMS_APPDEPTCODE4,
            SZRSYMS_APPMAJORCONCCODE4,
            SZRSYMS_APPTERM5,
            SZRSYMS_APPNUM5,
            SZRSYMS_APPLVLCODE5,
            SZRSYMS_APPSTYPCODE5,
            SZRSYMS_APPRESD5,
            SZRSYMS_APPFPTIME5,
            SZRSYMS_APPDECISION5,
            SZRSYMS_APPDECDATE5,
            SZRSYMS_APPLDATE5,
            SZRSYMS_APPCAMPUS5,
            SZRSYMS_APPCOLLCODE5,
            SZRSYMS_APPDEGCODE5,
            SZRSYMS_APPMAJCODE5,
            SZRSYMS_APPPGMCODE5,
            SZRSYMS_APPDEPTCODE5,
            SZRSYMS_APPMAJORCONCCODE5,
            SZRSYMS_REGTERM,
            SZRSYMS_REGLVLCODE,
            SZRSYMS_REGSTYPCODE,
            SZRSYMS_REGRESD,
            SZRSYMS_REGFPTIME,
            SZRSYMS_REGCAMPUS,
            SZRSYMS_REGCOLLEGE,
            SZRSYMS_REGDEGREE,
            SZRSYMS_REGMAJOR,
            SZRSYMS_REGPROGRAM,
            SZRSYMS_REGDEPTCODE,
            SZRSYMS_REGMAJORCONCCODE,
            SZRSYMS_LASTTERMENROLLED,
            SZRSYMS_GPALVL1,
            SZRSYMS_GPALVL2,
            SZRSYMS_GPALVL3,
            SZRSYMS_GPALVL4,
            SZRSYMS_FUNDSOURCE,
            SZRSYMS_SZRADDDATE,
            SZRSYMS_SZRACTIVITYDATE,
			SZRSYMS_EXTERNALEMAIL --RFC 561753 - NTOURNEY - 21-FEB-2023
        )
        VALUES
        (
            getExistingRec_rec.SZBSYMS_PIDM,
            getExistingRec_rec.SZBSYMS_USERNAME,
            getExistingRec_rec.SZBSYMS_STUDENTID,
            getExistingRec_rec.SZBSYMS_FIRSTNAME,
            getExistingRec_rec.SZBSYMS_LASTNAME,
            getExistingRec_rec.SZBSYMS_FULLNAME, 
            getExistingRec_rec.SZBSYMS_MIDDLENAME,
            getExistingRec_rec.SZBSYMS_PREFNAME,
            getExistingRec_rec.SZBSYMS_EMAIL,
            getExistingRec_rec.SZBSYMS_PHONE, -- changed April 2024 GM fullphone
            getExistingRec_rec.SZBSYMS_BIRTHDATE,
            getExistingRec_rec.SZBSYMS_GENDER,
            getExistingRec_rec.SZBSYMS_PRONOUN,
            getExistingRec_rec.SZBSYMS_ETHNICITY,
            getExistingRec_rec.SZBSYMS_CITIZENSHIP,
            getExistingRec_rec.SZBSYMS_PERMSTREETLINE1,
            getExistingRec_rec.SZBSYMS_PERMSTREETLINE2,
            getExistingRec_rec.SZBSYMS_PERMSTREETLINE3,
            getExistingRec_rec.SZBSYMS_PERMCITY,
            getExistingRec_rec.SZBSYMS_PERMPROV,
            getExistingRec_rec.SZBSYMS_PERMPOSTCODE,
            getExistingRec_rec.SZBSYMS_PERMCOUNTRY,
            getExistingRec_rec.SZBSYMS_CURRSTREETLINE1,
            getExistingRec_rec.SZBSYMS_CURRSTREETLINE2,
            getExistingRec_rec.SZBSYMS_CURRSTREETLINE3,
            getExistingRec_rec.SZBSYMS_CURRCITY,
            getExistingRec_rec.SZBSYMS_CURRPROV,
            getExistingRec_rec.SZBSYMS_CURRPOSTCODE,
            getExistingRec_rec.SZBSYMS_CURRCOUNTRY,
            getExistingRec_rec.SZBSYMS_DISABILITY,
            getExistingRec_rec.SZBSYMS_EMRCONTFNAME,
            getExistingRec_rec.SZBSYMS_EMRCONTLNAME,
            getExistingRec_rec.SZBSYMS_EMRCONTRELTN,
            getExistingRec_rec.SZBSYMS_EMRCONTPHONE,
            getExistingRec_rec.SZBSYMS_RECTYPE,
            getExistingRec_rec.SZBSYMS_APPTERM1,
            getExistingRec_rec.SZBSYMS_APPNUM1,
            getExistingRec_rec.SZBSYMS_APPLVLCODE1,
            getExistingRec_rec.SZBSYMS_APPSTYPCODE1,
            getExistingRec_rec.SZBSYMS_APPRESD1,
            getExistingRec_rec.SZBSYMS_APPFPTIME1,
            getExistingRec_rec.SZBSYMS_APPDECISION1,
            getExistingRec_rec.SZBSYMS_APPDECDATE1,
            getExistingRec_rec.SZBSYMS_APPLDATE1,
            getExistingRec_rec.SZBSYMS_APPCAMPUS1,
            getExistingRec_rec.SZBSYMS_APPCOLLCODE1,
            getExistingRec_rec.SZBSYMS_APPDEGCODE1,
            getExistingRec_rec.SZBSYMS_APPMAJCODE1,
            getExistingRec_rec.SZBSYMS_APPPGMCODE1,
            getExistingRec_rec.SZBSYMS_APPDEPTCODE1,
            getExistingRec_rec.SZBSYMS_APPMAJORCONCCODE1,
            getExistingRec_rec.SZBSYMS_APPTERM2,
            getExistingRec_rec.SZBSYMS_APPNUM2,
            getExistingRec_rec.SZBSYMS_APPLVLCODE2,
            getExistingRec_rec.SZBSYMS_APPSTYPCODE2,
            getExistingRec_rec.SZBSYMS_APPRESD2,
            getExistingRec_rec.SZBSYMS_APPFPTIME2,
            getExistingRec_rec.SZBSYMS_APPDECISION2,
            getExistingRec_rec.SZBSYMS_APPDECDATE2,
            getExistingRec_rec.SZBSYMS_APPLDATE2,
            getExistingRec_rec.SZBSYMS_APPCAMPUS2,
            getExistingRec_rec.SZBSYMS_APPCOLLCODE2,
            getExistingRec_rec.SZBSYMS_APPDEGCODE2,
            getExistingRec_rec.SZBSYMS_APPMAJCODE2,
            getExistingRec_rec.SZBSYMS_APPPGMCODE2,
            getExistingRec_rec.SZBSYMS_APPDEPTCODE2,
            getExistingRec_rec.SZBSYMS_APPMAJORCONCCODE2,
            getExistingRec_rec.SZBSYMS_APPTERM3,
            getExistingRec_rec.SZBSYMS_APPNUM3,
            getExistingRec_rec.SZBSYMS_APPLVLCODE3,
            getExistingRec_rec.SZBSYMS_APPSTYPCODE3,
            getExistingRec_rec.SZBSYMS_APPRESD3,
            getExistingRec_rec.SZBSYMS_APPFPTIME3,
            getExistingRec_rec.SZBSYMS_APPDECISION3,
            getExistingRec_rec.SZBSYMS_APPDECDATE3,
            getExistingRec_rec.SZBSYMS_APPLDATE3,
            getExistingRec_rec.SZBSYMS_APPCAMPUS3,
            getExistingRec_rec.SZBSYMS_APPCOLLCODE3,
            getExistingRec_rec.SZBSYMS_APPDEGCODE3,
            getExistingRec_rec.SZBSYMS_APPMAJCODE3,
            getExistingRec_rec.SZBSYMS_APPPGMCODE3,
            getExistingRec_rec.SZBSYMS_APPDEPTCODE3,
            getExistingRec_rec.SZBSYMS_APPMAJORCONCCODE3,
            getExistingRec_rec.SZBSYMS_APPTERM4,
            getExistingRec_rec.SZBSYMS_APPNUM4,
            getExistingRec_rec.SZBSYMS_APPLVLCODE4,
            getExistingRec_rec.SZBSYMS_APPSTYPCODE4,
            getExistingRec_rec.SZBSYMS_APPRESD4,
            getExistingRec_rec.SZBSYMS_APPFPTIME4,
            getExistingRec_rec.SZBSYMS_APPDECISION4,
            getExistingRec_rec.SZBSYMS_APPDECDATE4,
            getExistingRec_rec.SZBSYMS_APPLDATE4,
            getExistingRec_rec.SZBSYMS_APPCAMPUS4,
            getExistingRec_rec.SZBSYMS_APPCOLLCODE4,
            getExistingRec_rec.SZBSYMS_APPDEGCODE4,
            getExistingRec_rec.SZBSYMS_APPMAJCODE4,
            getExistingRec_rec.SZBSYMS_APPPGMCODE4,
            getExistingRec_rec.SZBSYMS_APPDEPTCODE4,
            getExistingRec_rec.SZBSYMS_APPMAJORCONCCODE4,
            getExistingRec_rec.SZBSYMS_APPTERM5,
            getExistingRec_rec.SZBSYMS_APPNUM5,
            getExistingRec_rec.SZBSYMS_APPLVLCODE5,
            getExistingRec_rec.SZBSYMS_APPSTYPCODE5,
            getExistingRec_rec.SZBSYMS_APPRESD5,
            getExistingRec_rec.SZBSYMS_APPFPTIME5,
            getExistingRec_rec.SZBSYMS_APPDECISION5,
            getExistingRec_rec.SZBSYMS_APPDECDATE5,
            getExistingRec_rec.SZBSYMS_APPLDATE5,
            getExistingRec_rec.SZBSYMS_APPCAMPUS5,
            getExistingRec_rec.SZBSYMS_APPCOLLCODE5,
            getExistingRec_rec.SZBSYMS_APPDEGCODE5,
            getExistingRec_rec.SZBSYMS_APPMAJCODE5,
            getExistingRec_rec.SZBSYMS_APPPGMCODE5,
            getExistingRec_rec.SZBSYMS_APPDEPTCODE5,
            getExistingRec_rec.SZBSYMS_APPMAJORCONCCODE5,
            getExistingRec_rec.SZBSYMS_REGTERM,
            getExistingRec_rec.SZBSYMS_REGLVLCODE,
            getExistingRec_rec.SZBSYMS_REGSTYPCODE,
            getExistingRec_rec.SZBSYMS_REGRESD,
            getExistingRec_rec.SZBSYMS_REGFPTIME,
            getExistingRec_rec.SZBSYMS_REGCAMPUS,
            getExistingRec_rec.SZBSYMS_REGCOLLEGE,
            getExistingRec_rec.SZBSYMS_REGDEGREE,
            getExistingRec_rec.SZBSYMS_REGMAJOR,
            getExistingRec_rec.SZBSYMS_REGPROGRAM,
            getExistingRec_rec.SZBSYMS_REGDEPTCODE,
            getExistingRec_rec.SZBSYMS_REGMAJORCONCCODE,
            getExistingRec_rec.SZBSYMS_LASTTERMENROLLED,
            getExistingRec_rec.SZBSYMS_GPALVL1,
            getExistingRec_rec.SZBSYMS_GPALVL2,
            getExistingRec_rec.SZBSYMS_GPALVL3,
            getExistingRec_rec.SZBSYMS_GPALVL4,
            getExistingRec_rec.SZBSYMS_FUNDSOURCE,
            sysdate,
            sysdate,
			getExistingRec_rec.SZBSYMS_EXTERNALEMAIL --RFC 561753 - NTOURNEY - 21-FEB-2023
        );
        commit;
        
        close getExistingRec_c;
    
    END insert_szrsyms_p;


-- Start Proc
BEGIN
     --pidm_Parameter := 10502305; --- ********* for testing **********
    
-- Start App
    open getAppsPidm_c;
    loop
        fetch getAppsPidm_c into getAppsPidm_rec;
        exit when getAppsPidm_c%notfound;
        
        appInsertSZR := 'N';     
        stuPidm := getAppsPidm_rec.szvaprd_pidm;
        
        --*******for testing******
        /* */
        subjct := 'getAppsPidm_c PIDM: ';
            msg := stuPidm;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;
            /* */
        --*******for testing******
        
        getApps_rec := null;
        
        open getApps_c(stuPidm);
        loop
            fetch getApps_c into getApps_rec;
            exit when getApps_c%notfound;

            termCode := null;
            appNum := null;
            lvlCode := null;
            sTypCode := null;
            resdCode := null;
            fPTimeInd := null;      
            appDecision := null;
            appDecDate := null;
            
            
            if getApps_c%rowcount = 1 then
                recordType := 'APP';
                
                getUserName_p(stuPidm);

                getStudentDetails_p(stuPidm);

                getStuPersDetails_p(stuPidm);

                getPermAddr_p(stuPidm);
                
                getCurrAddr_p(stuPidm);
            
                getStudentContact_p(stuPidm);
                
                getEmrContact_p(stuPidm);
                                          
                getDisability_p(stuPidm);
               
                termCode := getApps_rec.szvaprd_term_code_entry;
                appNum := getApps_rec.szvaprd_appl_no;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getApps_rec.szvaprd_levl_code;
                --lvlCode := getApps_rec.szvaprd_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getApps_rec.szvaprd_styp_code;
                --sTypCode := getApps_rec.szvaprd_styp_code;
                
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getApps_rec.szvaprd_resd_code;
                --appResdCode := getApps_rec.szvaprd_resd_code;
                
                fPTimeInd := getApps_rec.szvaprd_full_part_ind;               
                
                select stvapdc_desc into appDecisionDesc
                from stvapdc where stvapdc_code = getApps_rec.szvaprd_apdc_code;
                --appDecision := getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
                
                appDecDate := to_date(to_char(getApps_rec.szvaprd_apdc_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
				
				applDate := to_date(to_char(getApps_rec.szvaprd_appl_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                
                getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
                --campus := getApps_rec.szvaprd_camp_code;
                		
                getCollege_p(getApps_rec.szvaprd_coll_code_1, stuPidm);
                --collegeCode := getApps_rec.szvaprd_coll_code_1;
                        
                getDegree_p(getApps_rec.szvaprd_degc_code_1, stuPidm);
                --degreeCode := getApps_rec.szvaprd_degc_code_1;
                        
                getMajor_p(getApps_rec.szvaprd_majr_code_1, stuPidm);
                --majorCode := getApps_rec.szvaprd_majr_code_1;
                
				getDepartament_p(getApps_rec.szvaprd_dept_code, stuPidm);
				
				getMajorConcentration_p(getApps_rec.szvaprd_majr_code_conc_1, stuPidm);
				
                programCode := getApps_rec.szvaprd_saradap_program_1;
                        
                getGPA_p(stuPidm);
                        
                getFundSrc_p(getApps_rec.szvaprd_term_code_entry, stuPidm);
                                        
                getLastTermEnrolled_p(stuPidm);
                                               
                
                --Check if the same student application record exists.
                getSameAppRec_p(stuPidm, userName, studentID, firstName, lastName, fullName, middleName, prefName, stuEmail, fullPhone, birthDate, 
                                    gender, pronoun, ethnicity, citzDesc, permStreetLine1, permStreetLine2,  permStreetLine3,  permCity, permProv,  
                                    permPostCode,  permCountry,  currStreetLine1,  currStreetLine2, currStreetLine3,  currCity, 
                                    currProv,  currPostCode,  currCountry, emrContactFName, emrContactLName, emrContactReltn, 
                                    emrContactPhone, disabilityStatus, recordType, termCode, appNum, lvlDesc, sTypDesc, resdCode,
                                    fPTimeInd, appDecisionDesc, appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode,
                                    deptDesc, majorConcDesc, lastTermEnrolled, gpaLvl1, gpaLvl2, gpaLvl3, gpaLvl4, fundSrcDesc, externalEmail);
                                                    
                --If the same student application record does not exist, insert/update record.
                if toInsertUpdate = 'Y' then
                    --Check if a student application record exists, if yes, set flag to update.
                    getUpdate_p(stuPidm);
                    
                    --If student record exists, update record.
                    if toUpdate = 'Y' then
                        --If student registration exists, set case to 1.
                        select case when exists 
                                        (select SZBSYMS_pidm from SZBSYMS
                                        where SZBSYMS_pidm = stuPidm
                                        and (SZBSYMS_rectype = 'REG' or SZBSYMS_rectype = 'APP$REG'))
                                        --and SZBSYMS_rectype = 'REG') - Updated to the above on 2 NOV 2021 by PL - INC0101252 - FP RFC 561178.
                                    then 1
                                    else 0
                               end into idExist
                        from dual;
                        
                        if idExist = 1 then
                            recordType := 'APP$REG';
                            
                        end if;
            
                        --Insert old student record into history table.
                        if appInsertSZR = 'N' then
                            insert_szrsyms_p(stuPidm);
                            
                            appInsertSZR := 'Y';
                        end if;
                    
                        --getStudentContact_p(stuPidm); -- Added April 2024 GM

                        --Update existing record.
                        UPDATE SZBSYMS
                        SET SZBSYMS_PIDM = stuPidm,
                            SZBSYMS_USERNAME = userName,
                            SZBSYMS_STUDENTID = studentID,
                            SZBSYMS_FIRSTNAME = firstName,
                            SZBSYMS_LASTNAME = lastName,
                            SZBSYMS_FULLNAME = fullName,
                            SZBSYMS_MIDDLENAME = middleName,
                            SZBSYMS_PREFNAME = prefName,
                            SZBSYMS_EMAIL = stuEmail,
                            SZBSYMS_PHONE = fullPhone,
                            SZBSYMS_BIRTHDATE = birthDate,
                            SZBSYMS_GENDER = gender,
                            SZBSYMS_PRONOUN = pronoun,
                            SZBSYMS_ETHNICITY = ethnicity,
                            SZBSYMS_CITIZENSHIP = citzDesc,
                            SZBSYMS_PERMSTREETLINE1 = permStreetLine1,
                            SZBSYMS_PERMSTREETLINE2 = permStreetLine2,
                            SZBSYMS_PERMSTREETLINE3 = permStreetLine3,
                            SZBSYMS_PERMCITY = permCity,
                            SZBSYMS_PERMPROV = permProv,
                            SZBSYMS_PERMPOSTCODE = permPostCode,
                            SZBSYMS_PERMCOUNTRY = permCountry,
                            SZBSYMS_CURRSTREETLINE1 = currStreetLine1,
                            SZBSYMS_CURRSTREETLINE2 = currStreetLine2,
                            SZBSYMS_CURRSTREETLINE3 = currStreetLine3,
                            SZBSYMS_CURRCITY = currCity,
                            SZBSYMS_CURRPROV = currProv,
                            SZBSYMS_CURRPOSTCODE = currPostCode,
                            SZBSYMS_CURRCOUNTRY = currCountry,
                            SZBSYMS_EMRCONTFNAME = emrContactFName,
                            SZBSYMS_EMRCONTLNAME = emrContactLName,
                            SZBSYMS_EMRCONTRELTN = emrContactReltn,
                            SZBSYMS_EMRCONTPHONE = emrContactPhone,
                            SZBSYMS_DISABILITY = disabilityStatus,
                            SZBSYMS_RECTYPE = recordType,
                            SZBSYMS_APPTERM1 = termCode,
                            SZBSYMS_APPNUM1 = appNum,
                            SZBSYMS_APPLVLCODE1 = lvlDesc,
                            SZBSYMS_APPSTYPCODE1 = sTypDesc,
                            SZBSYMS_APPRESD1 = resdCode,
                            SZBSYMS_APPFPTIME1 = fPTimeInd,
                            SZBSYMS_APPDECISION1 = appDecisionDesc,
                            SZBSYMS_APPDECDATE1 = appDecDate,
                            SZBSYMS_APPLDATE1 = applDate,
                            SZBSYMS_APPCAMPUS1 = campus,
                            SZBSYMS_APPCOLLCODE1 = collegeCode,
                            SZBSYMS_APPDEGCODE1 = degreeCode,
                            SZBSYMS_APPMAJCODE1 = majorCode,
                            SZBSYMS_APPPGMCODE1 = programCode,
                            SZBSYMS_APPDEPTCODE1 = deptDesc,
                            SZBSYMS_APPMAJORCONCCODE1 = majorConcDesc,
                            SZBSYMS_LASTTERMENROLLED = lastTermEnrolled,
                            SZBSYMS_GPALVL1 = gpaLvl1,
                            SZBSYMS_GPALVL2 = gpaLvl2,
                            SZBSYMS_GPALVL3 = gpaLvl3,
                            SZBSYMS_GPALVL4 = gpaLvl4,
                            SZBSYMS_FUNDSOURCE = fundSrcDesc,
                            SZBSYMS_ACTIVITYDATE = sysdate,
							SZBSYMS_EXTERNALEMAIL = externalEmail --RFC 561753 - NTOURNEY - 21-FEB-2023
                        WHERE SZBSYMS_PIDM = stuPidm;
                    commit;
                    --If student record does not exist, insert record.
                    else

                        insert_szbsyms_p(stuPidm, userName, studentID, firstName, lastName, fullName, middleName, prefName, stuEmail, fullPhone, birthDate, 
                                        gender, pronoun, ethnicity, citzDesc, permStreetLine1, permStreetLine2,  permStreetLine3,  permCity, permProv,  
                                        permPostCode,  permCountry,  currStreetLine1,  currStreetLine2, currStreetLine3,  currCity, 
                                        currProv,  currPostCode,  currCountry, emrContactFName, emrContactLName, emrContactReltn, 
                                        emrContactPhone, disabilityStatus, recordType, termCode, appNum, lvlDesc, sTypDesc, resdCode,
                                        fPTimeInd, appDecisionDesc, appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, 
                                        null, null, null, null, null, null, null, null, null, null, null, null,
                                        lastTermEnrolled, gpaLvl1, gpaLvl2, gpaLvl3, gpaLvl4, fundSrcDesc, externalEmail);
                        
                        appInsertSZR := 'Y';
                        
                    end if;
                                    
                end if;                                


            elsif getApps_c%rowcount = 2 then                

                termCode := getApps_rec.szvaprd_term_code_entry;
                appNum := getApps_rec.szvaprd_appl_no;
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getApps_rec.szvaprd_levl_code;
                --lvlCode := getApps_rec.szvaprd_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getApps_rec.szvaprd_styp_code;
                --sTypCode := getApps_rec.szvaprd_styp_code;
                
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getApps_rec.szvaprd_resd_code;
                --appResdCode := getApps_rec.szvaprd_resd_code;
                
                fPTimeInd := getApps_rec.szvaprd_full_part_ind;               
                
                select stvapdc_desc into appDecisionDesc
                from stvapdc where stvapdc_code = getApps_rec.szvaprd_apdc_code;
                --appDecision := getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
                
                appDecDate := to_date(to_char(getApps_rec.szvaprd_apdc_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                applDate   := to_date(to_char(getApps_rec.szvaprd_appl_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                
                getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
                --campus := getApps_rec.szvaprd_camp_code;
                
                getCollege_p(getApps_rec.szvaprd_coll_code_1, stuPidm);
                --collegeCode := getApps_rec.szvaprd_coll_code_1;
                
                getDegree_p(getApps_rec.szvaprd_degc_code_1, stuPidm);
                --degreeCode := getApps_rec.szvaprd_degc_code_1;
                
                getMajor_p(getApps_rec.szvaprd_majr_code_1, stuPidm);
                --majorCode := getApps_rec.szvaprd_majr_code_1;
                
                getDepartament_p(getApps_rec.szvaprd_dept_code, stuPidm);
                
                getMajorConcentration_p(getApps_rec.szvaprd_majr_code_conc_1, stuPidm);
                
                programCode := getApps_rec.szvaprd_saradap_program_1;
                      
                --Check if the same student application record exists for app 2.
                getSameAppsRec_p(stuPidm, termCode, appNum, lvlDesc, sTypDesc, resdCode, fPTimeInd, appDecisionDesc,
                                appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, getApps_c%rowcount);
                                
                --If the same student application record 2 does not exist, update record 2.
                if toInsertUpdate = 'Y' then
                    --Check the history table to see if an entry was entered for rowCount 1.  If not, set flag to update(Y).
                    if appInsertSZR = 'N' then
                            insert_szrsyms_p(stuPidm);
                            
                            appInsertSZR := 'Y';
                    end if;
                           
                    --getStudentContact_p(stuPidm); -- Added April 2024 GM
                                         
                    UPDATE SZBSYMS
                    SET SZBSYMS_APPTERM2 = termCode,
                        SZBSYMS_APPNUM2 = appNum,
                        SZBSYMS_APPLVLCODE2 = lvlDesc, --lvlCode,
                        SZBSYMS_APPSTYPCODE2 = sTypDesc, --sTypCode,
                        SZBSYMS_APPRESD2 = resdCode,
                        SZBSYMS_APPFPTIME2 = fPTimeInd,
                        SZBSYMS_APPDECISION2 = appDecisionDesc, --appDecision,
                        SZBSYMS_APPDECDATE2 = appDecDate,
                        SZBSYMS_APPLDATE2 = applDate,
                        SZBSYMS_APPCAMPUS2 = campus,
                        SZBSYMS_APPCOLLCODE2 = collegeCode,
                        SZBSYMS_APPDEGCODE2 = degreeCode,
                        SZBSYMS_APPMAJCODE2 = majorCode,
                        SZBSYMS_APPPGMCODE2 = programCode,
                        SZBSYMS_APPDEPTCODE2 = deptDesc,
                        SZBSYMS_APPMAJORCONCCODE2 = majorConcDesc,
                        --SZBSYMS.SZBSYMS_PHONE = fullPhone, --Nigel commented
                        SZBSYMS_ACTIVITYDATE = sysdate 
                    WHERE SZBSYMS_STUDENTID = studentID;
                  commit;                
                end if;

            elsif getApps_c%rowcount = 3 then                

                termCode := getApps_rec.szvaprd_term_code_entry;
                appNum := getApps_rec.szvaprd_appl_no;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getApps_rec.szvaprd_levl_code;
                --lvlCode := getApps_rec.szvaprd_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getApps_rec.szvaprd_styp_code;
                --sTypCode := getApps_rec.szvaprd_styp_code;
                
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getApps_rec.szvaprd_resd_code;
                --appResdCode := getApps_rec.szvaprd_resd_code;
                
                fPTimeInd := getApps_rec.szvaprd_full_part_ind;               
                
                select stvapdc_desc into appDecisionDesc
                from stvapdc where stvapdc_code = getApps_rec.szvaprd_apdc_code;
                --appDecision := getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
                
                appDecDate := to_date(to_char(getApps_rec.szvaprd_apdc_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                applDate   := to_date(to_char(getApps_rec.szvaprd_appl_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                
                getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
                --campus := getApps_rec.szvaprd_camp_code;
                
                getCollege_p(getApps_rec.szvaprd_coll_code_1, stuPidm);
                --collegeCode := getApps_rec.szvaprd_coll_code_1;
                
                getDegree_p(getApps_rec.szvaprd_degc_code_1, stuPidm);
                --degreeCode := getApps_rec.szvaprd_degc_code_1;
                
                getMajor_p(getApps_rec.szvaprd_majr_code_1, stuPidm);
                --majorCode := getApps_rec.szvaprd_majr_code_1;
                
                programCode := getApps_rec.szvaprd_saradap_program_1;
                
                getDepartament_p(getApps_rec.szvaprd_dept_code, stuPidm);
                
                getMajorConcentration_p(getApps_rec.szvaprd_majr_code_conc_1, stuPidm);
                
                getSameAppsRec_p(stuPidm, termCode, appNum, lvlDesc, sTypDesc, resdCode, fPTimeInd, appDecisionDesc,
                                appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, getApps_c%rowcount);
                
                if toInsertUpdate = 'Y' then
                    
                    if appInsertSZR = 'N' then
                            insert_szrsyms_p(stuPidm);
                            
                            appInsertSZR := 'Y';
                    end if;
                           
                    --getStudentContact_p(stuPidm); -- Added April 2024 GM
                                                 
                    UPDATE SZBSYMS
                    SET SZBSYMS_APPTERM3 = termCode,
                        SZBSYMS_APPNUM3 = appNum,
                        SZBSYMS_APPLVLCODE3 = lvlDesc, --lvlCode,
                        SZBSYMS_APPSTYPCODE3 = sTypDesc, --sTypCode,
                        SZBSYMS_APPRESD3 = resdCode,
                        SZBSYMS_APPFPTIME3 = fPTimeInd,
                        SZBSYMS_APPDECISION3 = appDecisionDesc, --appDecision,
                        SZBSYMS_APPDECDATE3 = appDecDate,
                        SZBSYMS_APPLDATE3 = applDate,
                        SZBSYMS_APPCAMPUS3 = campus,
                        SZBSYMS_APPCOLLCODE3 = collegeCode,
                        SZBSYMS_APPDEGCODE3 = degreeCode,
                        SZBSYMS_APPMAJCODE3 = majorCode,
                        SZBSYMS_APPPGMCODE3 = programCode,
                        SZBSYMS_APPDEPTCODE3 = deptDesc,
                        SZBSYMS_APPMAJORCONCCODE3 = majorConcDesc,
                        --SZBSYMS.SZBSYMS_PHONE = fullPhone, --Nigel commented
                        SZBSYMS_ACTIVITYDATE = sysdate 
                    WHERE SZBSYMS_STUDENTID = studentID;
                    commit;
                end if;
                
            elsif getApps_c%rowcount = 4 then                

                termCode := getApps_rec.szvaprd_term_code_entry;
                appNum := getApps_rec.szvaprd_appl_no;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getApps_rec.szvaprd_levl_code;
                --lvlCode := getApps_rec.szvaprd_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getApps_rec.szvaprd_styp_code;
                --sTypCode := getApps_rec.szvaprd_styp_code;
                
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getApps_rec.szvaprd_resd_code;
                --appResdCode := getApps_rec.szvaprd_resd_code;
                
                fPTimeInd := getApps_rec.szvaprd_full_part_ind;               
                
                select stvapdc_desc into appDecisionDesc
                from stvapdc where stvapdc_code = getApps_rec.szvaprd_apdc_code;
                --appDecision := getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
                
                appDecDate := to_date(to_char(getApps_rec.szvaprd_apdc_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                applDate   := to_date(to_char(getApps_rec.szvaprd_appl_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                
                getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
                --campus := getApps_rec.szvaprd_camp_code;
                
                getCollege_p(getApps_rec.szvaprd_coll_code_1, stuPidm);
                --collegeCode := getApps_rec.szvaprd_coll_code_1;
                
                getDegree_p(getApps_rec.szvaprd_degc_code_1, stuPidm);
                --degreeCode := getApps_rec.szvaprd_degc_code_1;
                
                getMajor_p(getApps_rec.szvaprd_majr_code_1, stuPidm);
                --majorCode := getApps_rec.szvaprd_majr_code_1;
                
                programCode := getApps_rec.szvaprd_saradap_program_1;
                
                getDepartament_p(getApps_rec.szvaprd_dept_code, stuPidm);
                
                getMajorConcentration_p(getApps_rec.szvaprd_majr_code_conc_1, stuPidm);
                
                getSameAppsRec_p(stuPidm, termCode, appNum, lvlDesc, sTypDesc, resdCode, fPTimeInd, appDecisionDesc,
                                appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, getApps_c%rowcount);
                
                if toInsertUpdate = 'Y' then
                    
                    if appInsertSZR = 'N' then
                            insert_szrsyms_p(stuPidm);
                            
                            appInsertSZR := 'Y';
                    end if;
                             
                    --getStudentContact_p(stuPidm); -- Added April 2024 GM
                                               
                    UPDATE SZBSYMS
                    SET SZBSYMS_APPTERM4 = termCode,
                        SZBSYMS_APPNUM4 = appNum,
                        SZBSYMS_APPLVLCODE4 = lvlDesc, --lvlCode,
                        SZBSYMS_APPSTYPCODE4 = sTypDesc, --sTypCode,
                        SZBSYMS_APPRESD4 = resdCode,
                        SZBSYMS_APPFPTIME4 = fPTimeInd,
                        SZBSYMS_APPDECISION4 = appDecisionDesc, --appDecision,
                        SZBSYMS_APPDECDATE4 = appDecDate,
                        SZBSYMS_APPLDATE4 = applDate,
                        SZBSYMS_APPCAMPUS4 = campus,
                        SZBSYMS_APPCOLLCODE4 = collegeCode,
                        SZBSYMS_APPDEGCODE4 = degreeCode,
                        SZBSYMS_APPMAJCODE4 = majorCode,
                        SZBSYMS_APPPGMCODE4 = programCode,
                        SZBSYMS_APPDEPTCODE4 = deptDesc,
                        SZBSYMS_APPMAJORCONCCODE4 = majorConcDesc,
                        --SZBSYMS.SZBSYMS_PHONE = fullPhone, --Nigel commented
                        SZBSYMS_ACTIVITYDATE = sysdate 
                    WHERE SZBSYMS_STUDENTID = studentID;
                    commit;
                end if;
                
            elsif getApps_c%rowcount = 5 then                

                termCode := getApps_rec.szvaprd_term_code_entry;
                appNum := getApps_rec.szvaprd_appl_no;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getApps_rec.szvaprd_levl_code;
                --lvlCode := getApps_rec.szvaprd_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getApps_rec.szvaprd_styp_code;
                --sTypCode := getApps_rec.szvaprd_styp_code;
                
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getApps_rec.szvaprd_resd_code;
                --appResdCode := getApps_rec.szvaprd_resd_code;
                
                fPTimeInd := getApps_rec.szvaprd_full_part_ind;               
                
                select stvapdc_desc into appDecisionDesc
                from stvapdc where stvapdc_code = getApps_rec.szvaprd_apdc_code;
                --appDecision := getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
                
                appDecDate := to_date(to_char(getApps_rec.szvaprd_apdc_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                applDate := to_date(to_char(getApps_rec.szvaprd_appl_Date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                                                        
                getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
                --campus := getApps_rec.szvaprd_camp_code;
                
                getCollege_p(getApps_rec.szvaprd_coll_code_1, stuPidm);
                --collegeCode := getApps_rec.szvaprd_coll_code_1;
                
                getDegree_p(getApps_rec.szvaprd_degc_code_1, stuPidm);
                --degreeCode := getApps_rec.szvaprd_degc_code_1;
                
                getMajor_p(getApps_rec.szvaprd_majr_code_1, stuPidm);
                --majorCode := getApps_rec.szvaprd_majr_code_1;
                
                programCode := getApps_rec.szvaprd_saradap_program_1;
                
                getDepartament_p(getApps_rec.szvaprd_dept_code, stuPidm);
                
                getMajorConcentration_p(getApps_rec.szvaprd_majr_code_conc_1, stuPidm);
                
                getSameAppsRec_p(stuPidm, termCode, appNum, lvlDesc, sTypDesc, resdCode, fPTimeInd, appDecisionDesc,
                                appDecDate, applDate, campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, getApps_c%rowcount);
                
                if toInsertUpdate = 'Y' then
                    
                    if appInsertSZR = 'N' then
                            insert_szrsyms_p(stuPidm);
                            
                            appInsertSZR := 'Y';

                    end if;
                    
                    --getStudentContact_p(stuPidm); -- Added April 2024 GM
                                
                    UPDATE SZBSYMS
                    SET SZBSYMS_APPTERM5 = termCode,
                        SZBSYMS_APPNUM5 = appNum,
                        SZBSYMS_APPLVLCODE5 = lvlDesc, --lvlCode,
                        SZBSYMS_APPSTYPCODE5 = sTypDesc, --sTypCode,
                        SZBSYMS_APPRESD5 = resdCode,
                        SZBSYMS_APPFPTIME5 = fPTimeInd,
                        SZBSYMS_APPDECISION5 = appDecisionDesc, --appDecision,
                        SZBSYMS_APPDECDATE5 = appDecDate,
                        SZBSYMS_APPLDATE5 = applDate,
                        SZBSYMS_APPCAMPUS5 = campus,
                        SZBSYMS_APPCOLLCODE5 = collegeCode,
                        SZBSYMS_APPDEGCODE5 = degreeCode,
                        SZBSYMS_APPMAJCODE5 = majorCode,
                        SZBSYMS_APPPGMCODE5 = programCode,
                        SZBSYMS_APPDEPTCODE5 = deptDesc,
                        SZBSYMS_APPMAJORCONCCODE5 = majorConcDesc,
                        --SZBSYMS.SZBSYMS_PHONE = fullPhone, --Nigel commented
                        SZBSYMS_ACTIVITYDATE = sysdate 
                    WHERE SZBSYMS_STUDENTID = studentID;
                    commit;
                end if;
                               
--            else            
--            
--                appTermCode := appTermCode || '$' ||getApps_rec.szvaprd_term_code_entry;
--                appNum := appNum || '$' || getApps_rec.szvaprd_appl_no;
--                appLvlCode := appLvlCode || '$' || getApps_rec.szvaprd_levl_code;
--                appSTypCode := appSTypCode || '$' || getApps_rec.szvaprd_styp_code;
--                appResdCode := appResdCode || '$' || getApps_rec.szvaprd_resd_code;
--                appFPTime := appFPTime || '$' || getApps_rec.szvaprd_full_part_ind;               
--                appDecision := appDecision || '$' || getApps_rec.szvaprd_apdc_code;  --szvaprd/sarappd
--                appDecDate := appDecDAte || '$' || to_char(getApps_rec.szvaprd_apdc_date,'MM/DD/YYYY');
--                
--                if campusOld is null then
--                    campusOld := campus;
--                    getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
--                    campusNew := campusOld || '$' || campus;
--                else
--                    campusOld := campusNew;
--                    getCampus_p(getApps_rec.szvaprd_camp_code, stuPidm);
--                    campusNew := campusOld || '$' || campus;
--                end if;
--                --campus := campus || '$' || getApps_rec.szvaprd_camp_code;
--                
--                collegeCode := collegeCode || '$' || getApps_rec.szvaprd_coll_code_1;
--                
--                degreeCode :=  degreeCode || '$' || getApps_rec.szvaprd_degc_code_1;
--               
--                majorCode := majorCode || '$' || getApps_rec.szvaprd_majr_code_1;
--                
--                programCode := programCode || '$' || getApps_rec.szvaprd_saradap_program_1;
--                
--                UPDATE SZBSYMS
--                SET SZBSYMS_APPTERM = appTermCode,
--                    SZBSYMS_APPNUM = appNum,
--                    SZBSYMS_LVLCODE = appLvlCode,
--                    SZBSYMS_STYPCODE = appSTypCode,
--                    SZBSYMS_RESDCODE = appResdCode,
--                    SZBSYMS_FPTIME = appFPTime,
--                    SZBSYMS_APPDECISION = appDecision,
--                    SZBSYMS_APPDECDATE = appDecDate,
--                    SZBSYMS_CAMPUS = campusNew,
--                    SZBSYMS_COLLCODE = collegeCode,
--                    SZBSYMS_DEGCODE = degreeCode,
--                    SZBSYMS_MAJCODE = majorCode,
--                    SZBSYMS_PGMCODE = programCode
--                WHERE SZBSYMS_STUDENTID = studentID;
--                
--                DBMS_OUTPUT.PUT_LINE(appDecision || ', ' || campus || ', ' || degreeCode|| ', ' || 
--                    programCode || ', EOR');
                    
            end if;      
           
        end loop;
        close getApps_c; 

    end loop;
    close getAppsPidm_c;

    COMMIT;
    
    -- Start Regs
    open getRegsPidm_c;
    loop
        fetch getRegsPidm_c into getRegsPidm_rec;
        exit when getRegsPidm_c%notfound;
        
        regInsertSZR := 'N';    
        stuPidm := getRegsPidm_rec.szvstcr_pidm;
        
        --*******for testing******
        subjct := 'getRegsPidm_c PIDM: ';
        msg := stuPidm;
        insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
        values (subjct, msg, sysdate); 
        commit;
        --*******for testing******
        
        getRegs_rec := null;
        
        open getRegs_c(stuPidm);
        fetch getRegs_c into getRegs_rec;
         
         -- Adding to skip not found regs GM Jan 26 2024
        if getRegs_c%notfound then
            subjct := 'getRegs_c(stuPidm) PIDM: ';
            msg := stuPidm;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
               values (subjct, msg, sysdate); 
            commit;
        else  
         -- End Adding to skip not found regs GM Jan 26 2024 
         /* */
            termCode := null;
            lvlCode := null;
            sTypCode := null;
            resdCode := null;
            fPTimeInd := null;      
                      
            recordType := 'REG';
            
            getUserName_p(stuPidm);
            
            getStudentDetails_p(stuPidm);
            
            --If student application exists, set case to 1.
            select case when exists 
                            (select SZBSYMS_pidm from SZBSYMS
                            where SZBSYMS_pidm = stuPidm
                            and (SZBSYMS_rectype = 'APP' or SZBSYMS_rectype = 'APP$REG'))
                        then 1
                        else 0
                   end into idExist
            from dual;
            
            --If student application doesn't exist, create a registration record.
            if idExist = 0 then
                getStuPersDetails_p(stuPidm);
                
                getPermAddr_p(stuPidm);
                
                getCurrAddr_p(stuPidm);
                                
                getStudentContact_p(stuPidm);
                
                getEmrContact_p(stuPidm);
                
                getDisability_p(stuPidm);
                
                termCode := getRegs_rec.szvestu_etrm_code;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getRegs_rec.szvestu_levl_code;
                --lvlCode := getRegs_rec.szvestu_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getRegs_rec.szvestu_styp_code;
                --sTypCode := getRegs_rec.szvestu_styp_code;
               
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getRegs_rec.szvestu_resd_code;
                
                fPTimeInd := getRegs_rec.szvestu_full_part_ind;
               
                getCampus_p(getRegs_rec.szvestu_camp_code, stuPidm);
                
                getCollege_p(getRegs_rec.szvestu_coll_code_1, stuPidm);
                
                getDegree_p(getRegs_rec.szvestu_degc_code_1, stuPidm);
                
                getMajor_p(getRegs_rec.szvestu_majr_code_1, stuPidm);

                programCode := getRegs_rec.szvestu_program_1;
                
                getDepartament_p(getRegs_rec.szvestu_dept_code, stuPidm);
				
                getMajorConcentration_p(getRegs_rec.szvestu_majr_code_conc_1, stuPidm);
        
                getGPA_p(stuPidm);
                
                getFundSrc_p(getRegs_rec.szvestu_etrm_code, stuPidm);
                
                getLastTermEnrolled_p(stuPidm);
                
--                DBMS_OUTPUT.PUT_LINE(stuPidm || ', ' || userName || ', ' || studentID || ', ' || firstName || ', ' || lastName || ', ' ||
--                    fullName || ', ' || middleName || ', ' || prefName || ', ' || stuEmail || ', ' || phone || ', ' || birthDate || ', ' || gender || ', ' || 
--                    pronoun || ', ' || permStreetLine1 || ', ' || permStreetLine2 || ', ' || permStreetLine3 || ', ' || permCity|| ', ' || 
--                    permProv || ', ' || permPostCode || ', ' || permCountry || ', ' || currStreetLine1 || ', ' || currStreetLine2 || ', ' || 
--                    currStreetLine3 || ', ' || currCity || ', ' || currProv || ', ' || currPostCode || ', ' || currCountry || ', ' ||
--                    emrContactFName || ', ' || emrContactLName || ', ' || emrContactReltn || ', ' || emrContactPhone || ', ' ||
--                    disabilityStatus || ', ' || recordType || ', ' || appDecision || ', ' || campus || ', ' || degreeCode|| ', ' || 
--                    programCode || ', EOR');
                
                --Check if the same student registration record exists.
                getSameRegRec_p(stuPidm, userName, studentID, firstName, lastName, fullName, middleName, prefName, stuEmail, fullPhone, birthDate, 
                                    gender, pronoun, ethnicity, citzDesc, permStreetLine1, permStreetLine2,  permStreetLine3,  permCity, permProv,  
                                    permPostCode,  permCountry,  currStreetLine1,  currStreetLine2, currStreetLine3,  currCity, 
                                    currProv,  currPostCode,  currCountry, emrContactFName, emrContactLName, emrContactReltn, 
                                    emrContactPhone, disabilityStatus, recordType, termCode, lvlDesc, sTypDesc, resdCode, fPTimeInd, 
                                    campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc,
                                    lastTermEnrolled, gpaLvl1, gpaLvl2, gpaLvl3, gpaLvl4, fundSrcDesc, externalEmail);

                --If the same student registration record does not exist, insert/update record.
                if toInsertUpdate = 'Y' then
                    --Check if a student registration record exists, if yes, set flag to update.
                    
                    getUpdate_p(stuPidm);
                     
                    --If student record exists, update record.
                    if toUpdate = 'Y' then
                                        
                        --Check the history table to see if a new entry was entered for app rowCount 1.  If not, set flag to update(Y).
                        insert_szrsyms_p(stuPidm);
                                                               
                        UPDATE SZBSYMS
                        SET SZBSYMS_PIDM = stuPidm,
                            SZBSYMS_USERNAME = userName,
                            SZBSYMS_STUDENTID = studentID,
                            SZBSYMS_FIRSTNAME = firstName,
                            SZBSYMS_LASTNAME = lastName,
                            SZBSYMS_FULLNAME = fullName,
                            SZBSYMS_MIDDLENAME = middleName,
                            SZBSYMS_PREFNAME = prefName,
                            SZBSYMS_EMAIL = stuEmail,
                            SZBSYMS_PHONE = fullPhone,
                            SZBSYMS_BIRTHDATE = birthDate,
                            SZBSYMS_GENDER = gender,
                            SZBSYMS_PRONOUN = pronoun,
                            SZBSYMS_ETHNICITY = ethnicity,
                            SZBSYMS_CITIZENSHIP = citzDesc,
                            SZBSYMS_PERMSTREETLINE1 = permStreetLine1,
                            SZBSYMS_PERMSTREETLINE2 = permStreetLine2,
                            SZBSYMS_PERMSTREETLINE3 = permStreetLine3,
                            SZBSYMS_PERMCITY = permCity,
                            SZBSYMS_PERMPROV = permProv,
                            SZBSYMS_PERMPOSTCODE = permPostCode,
                            SZBSYMS_PERMCOUNTRY = permCountry,
                            SZBSYMS_CURRSTREETLINE1 = currStreetLine1,
                            SZBSYMS_CURRSTREETLINE2 = currStreetLine2,
                            SZBSYMS_CURRSTREETLINE3 = currStreetLine3,
                            SZBSYMS_CURRCITY = currCity,
                            SZBSYMS_CURRPROV = currProv,
                            SZBSYMS_CURRPOSTCODE = currPostCode,
                            SZBSYMS_CURRCOUNTRY = currCountry,
                            SZBSYMS_EMRCONTFNAME = emrContactFName,
                            SZBSYMS_EMRCONTLNAME = emrContactLName,
                            SZBSYMS_EMRCONTRELTN = emrContactReltn,
                            SZBSYMS_EMRCONTPHONE = emrContactPhone,
                            SZBSYMS_DISABILITY = disabilityStatus,
                            SZBSYMS_RECTYPE = recordType,
                            SZBSYMS_REGTERM = termCode,
                            SZBSYMS_REGLVLCODE = lvlDesc,
                            SZBSYMS_REGSTYPCODE = sTypDesc,
                            SZBSYMS_REGRESD = resdCode,
                            SZBSYMS_REGFPTIME = fPTimeInd,
                            SZBSYMS_REGCAMPUS = campus,
                            SZBSYMS_REGCOLLEGE = collegeCode,
                            SZBSYMS_REGDEGREE = degreeCode,
                            SZBSYMS_REGMAJOR = majorCode,
                            SZBSYMS_REGPROGRAM = programCode,
                            SZBSYMS_REGDEPTCODE = deptDesc,   
                            SZBSYMS_REGMAJORCONCCODE = majorConcDesc,
                            SZBSYMS_LASTTERMENROLLED = lastTermEnrolled,
                            SZBSYMS_GPALVL1 = gpaLvl1,
                            SZBSYMS_GPALVL2 = gpaLvl2,
                            SZBSYMS_GPALVL3 = gpaLvl3,
                            SZBSYMS_GPALVL4 = gpaLvl4,
                            SZBSYMS_FUNDSOURCE = fundSrcDesc,
                            SZBSYMS_ACTIVITYDATE = sysdate,
							SZBSYMS_EXTERNALEMAIL = externalEmail --RFC 561753 - NTOURNEY - 21-FEB-2023
                        WHERE SZBSYMS_PIDM = stuPidm;
                    
                        commit;
                    --If registration record is new and does not exist, insert record.
                    else
                    
                        insert_szbsyms_p(stuPidm, userName, studentID, firstName, lastName, fullName, middleName, prefName, stuEmail, fullPhone, birthDate, 
                                        gender, pronoun, ethnicity, citzDesc, permStreetLine1, permStreetLine2,  permStreetLine3,  permCity, permProv,  
                                        permPostCode,  permCountry,  currStreetLine1,  currStreetLine2, currStreetLine3, currCity, 
                                        currProv,  currPostCode,  currCountry, emrContactFName, emrContactLName, emrContactReltn, 
                                        emrContactPhone, disabilityStatus, recordType, null, null, null, null, null, null,
                                        null, null, null, null, null, null, null, null, null, null, termCode, lvlDesc, sTypDesc, resdCode, fPTimeInd, 
                                        campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, 
                                        lastTermEnrolled, gpaLvl1, gpaLvl2, gpaLvl3, gpaLvl4, fundSrcDesc, externalEmail);
                                    
                    end if;
                    
                end if;
            
            --If an application record exists already, update with registration details.
            else 

                recordType := 'APP$REG';
                
                --RFC562440 NTOURNEY 01-OCT-2024
                --Added additional get functions to gather student data
                getStuPersDetails_p(stuPidm);
                
                getPermAddr_p(stuPidm);
                
                getCurrAddr_p(stuPidm);
                                
                getStudentContact_p(stuPidm);
                
                getEmrContact_p(stuPidm);
                
                getDisability_p(stuPidm);
                --RFC562440 NTOURNEY 01-OCT-2024 end addition
                
                termCode := getRegs_rec.szvestu_etrm_code;
                
                select stvlevl_desc into lvlDesc
                from stvlevl where stvlevl_code = getRegs_rec.szvestu_levl_code;
                --lvlCode := getRegs_rec.szvestu_levl_code;
                
                select stvstyp_desc into sTypDesc
                from stvstyp where stvstyp_code = getRegs_rec.szvestu_styp_code;
                --sTypCode := getRegs_rec.szvestu_styp_code;
               
                select stvresd_desc into resdCode
                from stvresd where stvresd_code = getRegs_rec.szvestu_resd_code;
                
                fPTimeInd := getRegs_rec.szvestu_full_part_ind;
               
                getCampus_p(getRegs_rec.szvestu_camp_code, stuPidm);
                
                getCollege_p(getRegs_rec.szvestu_coll_code_1, stuPidm);
                
                getDegree_p(getRegs_rec.szvestu_degc_code_1, stuPidm);
                
                getMajor_p(getRegs_rec.szvestu_majr_code_1, stuPidm);

                programCode := getRegs_rec.szvestu_program_1;
                
                getDepartament_p(getRegs_rec.szvestu_dept_code, stuPidm);
				
                getMajorConcentration_p(getRegs_rec.szvestu_majr_code_conc_1, stuPidm);

                --RFC562440 NTOURNEY 01-OCT-2024
                --Added additional get functions to gather student data
                getGPA_p(stuPidm);
                
                getFundSrc_p(getRegs_rec.szvestu_etrm_code, stuPidm);
                
                getLastTermEnrolled_p(stuPidm);

                --RFC562440 NTOURNEY 01-OCT-2024 end addition
                
                --Check if the same student registration details exist in current APP$REG record.
                --getSameRegsRec_p(stuPidm, termCode, lvlDesc, sTypDesc, resdCode, fPTimeInd, 
                                --campus, collegeCode, degreeCode, majorCode, programCode);
                
                --RFC562440 NTOURNEY 01-OCT-2024
                --Commented above, changed to use the same duplicate check procedure as REG record types, which checks all fields
                getSameRegRec_p(stuPidm, userName, studentID, firstName, lastName, fullName, middleName, prefName, stuEmail, fullPhone, birthDate, 
                                    gender, pronoun, ethnicity, citzDesc, permStreetLine1, permStreetLine2,  permStreetLine3,  permCity, permProv,  
                                    permPostCode,  permCountry,  currStreetLine1,  currStreetLine2, currStreetLine3,  currCity, 
                                    currProv,  currPostCode,  currCountry, emrContactFName, emrContactLName, emrContactReltn, 
                                    emrContactPhone, disabilityStatus, recordType, termCode, lvlDesc, sTypDesc, resdCode, fPTimeInd, 
                                    campus, collegeCode, degreeCode, majorCode, programCode, deptDesc, majorConcDesc, lastTermEnrolled, 
                                    gpaLvl1, gpaLvl2, gpaLvl3, gpaLvl4, fundSrcDesc, externalEmail);
                

                --If the same student registration details do not exist in the current APP$REG record, insert/update record.
                if toInsertUpdate = 'Y' then
                
                    --Check the history table to see if a new entry was entered for today.  If not, set flag to update(Y).
                    getUpdateSZR_p(stuPidm);
                                        
                    if toUpdateSZR = 'Y' then
                    
                        --Insert old student record into history table.
                        insert_szrsyms_p(stuPidm);
                        
                    end if;

                                                            
                    --Update existing record.
                    /*UPDATE SZBSYMS
                    SET SZBSYMS_RECTYPE = recordType,
                        SZBSYMS_REGTERM = termCode,
                        SZBSYMS_REGLVLCODE = lvlDesc, --lvlCode,
                        SZBSYMS_REGSTYPCODE = sTypDesc, --sTypCode,
                        SZBSYMS_REGRESD = resdCode,
                        SZBSYMS_REGFPTIME = fPTimeInd,
                        SZBSYMS_REGCAMPUS = campus,
                        SZBSYMS_REGCOLLEGE = collegeCode, 
                        SZBSYMS_REGDEGREE = degreeCode,
                        SZBSYMS_REGMAJOR = majorCode,
                        SZBSYMS_REGPROGRAM = programCode,
                        SZBSYMS_ACTIVITYDATE = sysdate 
                    WHERE SZBSYMS_STUDENTID = studentID;*/
                    
                    --RFC562440 NTOURNEY 01-OCT-2024
                    --Commented above, added more fields to the update
                    UPDATE SZBSYMS
                        SET SZBSYMS_PIDM = stuPidm,
                            SZBSYMS_USERNAME = userName,
                            SZBSYMS_STUDENTID = studentID,
                            SZBSYMS_FIRSTNAME = firstName,
                            SZBSYMS_LASTNAME = lastName,
                            SZBSYMS_FULLNAME = fullName,
                            SZBSYMS_MIDDLENAME = middleName,
                            SZBSYMS_PREFNAME = prefName,
                            SZBSYMS_EMAIL = stuEmail,
                            SZBSYMS_PHONE = fullPhone,
                            SZBSYMS_BIRTHDATE = birthDate,
                            SZBSYMS_GENDER = gender,
                            SZBSYMS_PRONOUN = pronoun,
                            SZBSYMS_ETHNICITY = ethnicity,
                            SZBSYMS_CITIZENSHIP = citzDesc,
                            SZBSYMS_PERMSTREETLINE1 = permStreetLine1,
                            SZBSYMS_PERMSTREETLINE2 = permStreetLine2,
                            SZBSYMS_PERMSTREETLINE3 = permStreetLine3,
                            SZBSYMS_PERMCITY = permCity,
                            SZBSYMS_PERMPROV = permProv,
                            SZBSYMS_PERMPOSTCODE = permPostCode,
                            SZBSYMS_PERMCOUNTRY = permCountry,
                            SZBSYMS_CURRSTREETLINE1 = currStreetLine1,
                            SZBSYMS_CURRSTREETLINE2 = currStreetLine2,
                            SZBSYMS_CURRSTREETLINE3 = currStreetLine3,
                            SZBSYMS_CURRCITY = currCity,
                            SZBSYMS_CURRPROV = currProv,
                            SZBSYMS_CURRPOSTCODE = currPostCode,
                            SZBSYMS_CURRCOUNTRY = currCountry,
                            SZBSYMS_EMRCONTFNAME = emrContactFName,
                            SZBSYMS_EMRCONTLNAME = emrContactLName,
                            SZBSYMS_EMRCONTRELTN = emrContactReltn,
                            SZBSYMS_EMRCONTPHONE = emrContactPhone,
                            SZBSYMS_DISABILITY = disabilityStatus,
                            SZBSYMS_RECTYPE = recordType,
                            SZBSYMS_REGTERM = termCode,
                            SZBSYMS_REGLVLCODE = lvlDesc,
                            SZBSYMS_REGSTYPCODE = sTypDesc,
                            SZBSYMS_REGRESD = resdCode,
                            SZBSYMS_REGFPTIME = fPTimeInd,
                            SZBSYMS_REGCAMPUS = campus,
                            SZBSYMS_REGCOLLEGE = collegeCode,
                            SZBSYMS_REGDEGREE = degreeCode,
                            SZBSYMS_REGMAJOR = majorCode,
                            SZBSYMS_REGPROGRAM = programCode,
                            SZBSYMS_REGDEPTCODE = deptDesc,   
                            SZBSYMS_REGMAJORCONCCODE = majorConcDesc,   
                            SZBSYMS_LASTTERMENROLLED = lastTermEnrolled,
                            SZBSYMS_GPALVL1 = gpaLvl1,
                            SZBSYMS_GPALVL2 = gpaLvl2,
                            SZBSYMS_GPALVL3 = gpaLvl3,
                            SZBSYMS_GPALVL4 = gpaLvl4,
                            SZBSYMS_FUNDSOURCE = fundSrcDesc,
                            SZBSYMS_ACTIVITYDATE = sysdate,
							SZBSYMS_EXTERNALEMAIL = externalEmail
                        WHERE SZBSYMS_PIDM = stuPidm;
                    
                    
                commit;
                end if;
            
            end if;
           -- Adding to skip not found regs GM Jan 26 2024
        end if;
           -- End of Adding to skip not found regs GM Jan 26 2024
--        end loop;
        close getRegs_c;

    end loop;
    close getRegsPidm_c;


COMMIT;


EXCEPTION
    WHEN OTHERS THEN
        rollback;
        subjct := 'symplicityStudentDataLoad Exception';
        msg := 'PIDM: ' || stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
            commit;


END symplicityStudentDataLoad;
/
