CREATE OR REPLACE PROCEDURE BANINST1.symplicityClassDataLoad is

/******************************************************************************
   NAME:       symplicityClassDataLoad
   PURPOSE:    Symplicity Accommodate Class Data Load
               This procedure pulls student data from various Banner tables and loads it into the SZBSYMC table

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
											
   1.1		  09-MAY-2023 Nigel Tourney		RFC 561854 - Increase minimum academic term from 202100 to 202200
   
   1.2        04-JUL-2023 Nigel Tourney     RFC 561933 - Change course start/end dates to pull from SSBSECT.
                                            We need the start/end dates to be the same for each student in the
                                            course, otherwise it was causing problems in Accommodate.
                                            
   1.3        11-SEP-2025 Nigel Tourney     RFC 562817 - Modified to stop sending duplicate instructors for a course.
                                            Bug fix to instructor email 17, it was always blank.
											
******************************************************************************/

    --Variables declarations.
    stuPidm         number(8);
    
    studentID       varchar(9);
    uniqueCrseID    varchar(22);
    crseTitle       varchar(75);  
    --crseTitle       varchar(30); - Updated to the above on 7 OCT 2021 by PL - INC0102671 - FP RFC 561130.
    crseNum         varchar(9);
    status          varchar(2);
    statusDesc      varchar(30);
    termCode        varchar(6);
    instrPidm       number(8);
    instrPidm2      number(8);
    instrPidm3      number(8);
    instrPidm4      number(8);
    instrPidm5      number(8);
    instrPidm6      number(8);
    instrPidm7      number(8);
    instrPidm8      number(8);
    instrPidm9      number(8);
    instrPidm10     number(8);
    instrPidm11     number(8);
    instrPidm12     number(8);
    instrPidm13     number(8);
    instrPidm14     number(8);
    instrPidm15     number(8);
    instrPidm16     number(8);
    instrPidm17     number(8);
    instrPidm18     number(8);
    instrPidm19     number(8);
    instrPidm20     number(8);
    instrEmail      varchar(128);
    instrEmail2     varchar(128);
    instrEmail3     varchar(128);
    instrEmail4     varchar(128);
    instrEmail5     varchar(128);
    instrEmail6     varchar(128);
    instrEmail7     varchar(128);
    instrEmail8     varchar(128);
    instrEmail9     varchar(128);
    instrEmail10    varchar(128);
    instrEmail11    varchar(128);
    instrEmail12    varchar(128);
    instrEmail13    varchar(128);
    instrEmail14    varchar(128);
    instrEmail15    varchar(128);
    instrEmail16    varchar(128);
    instrEmail17    varchar(128);
    instrEmail18    varchar(128);
    instrEmail19    varchar(128);
    instrEmail20    varchar(128);
    instrCnt        number;
    instrEmailCnt   number;
    emailCnt        number;
--    crseMon         varchar(1);
--    crseTue         varchar(1);
--    crseWed         varchar(1);
--    crseThu         varchar(1);
--    crseFri         varchar(1);
--    crseSat         varchar(1);
--    crseSun         varchar(1);
    crseDays        varchar(7);
    startTime       varchar(4);
    endTime         varchar(4);
    startDate       date;
    endDate         date;
    enrollEndDate   date;
    enrolled        varchar(1);
    enrollDate      date;
    gradeCode       varchar(6);
    gradeDate       date;
    creditHrs       number;
    
    toInsertUpdate  varchar2(1);
    toUpdate        varchar2(1);
    l_stvrstsInclSectEnrl stvrsts.STVRSTS_INCL_SECT_ENRL%type; --INC0141120 NTOURNEY 30-AUG-2022

    --Exception vars
    l_status        varchar2(20);
    frm_add         varchar2(128);
    to_add          varchar2(128) := 'JProgramAnalyst@saskpolytech.ca';
    cc_add          varchar2(128):= 'lop@saskpolytech.ca';
    subjct          varchar2(150);
    msg             varchar2(10000);


    
    --Cursor to retrieve an existing class record for a student.
    cursor getExistingRec_c (c_pidm number, c_uniqCrseID varchar2) is
        
        select * from szbsymc
        where szbsymc_pidm = c_pidm
        and szbsymc_uniqcrseid = c_uniqCrseID;
    
    getExistingRec_rec        getExistingRec_c%rowtype;
    
    
    --Cursor to retrieve class meeting times.
    cursor getMeetTimes_c(c_termCode varchar2, c_crn varchar2) is
        
        select ssrmeet_mon_day,
               ssrmeet_tue_day,
               ssrmeet_wed_day,
               ssrmeet_thu_day,
               ssrmeet_fri_day,
               ssrmeet_sat_day,
               ssrmeet_sun_day,
               ssrmeet_begin_time,
               ssrmeet_end_time
        from ssrmeet
        where ssrmeet_term_code = c_termCode
        and ssrmeet_crn = c_crn;
    
    getMeetTimes_rec    getMeetTimes_c%rowtype;

    
    --Cursor to retrieve all the student's registered classes.
    --NTOURNEY RFC561933 04-JUL-2023 - Changed course start/end dates to pull from SSBSECT.
    --We need the start/end dates to be the same for each student in the
    --course, otherwise it was causing problems in Accommodate.
    cursor getRegClasses_c(c_stuPidm number) is
        
        select a.*, 
               b.SSBSECT_PTRM_CODE,
               b.SSBSECT_PTRM_START_DATE,
               b.SSBSECT_PTRM_END_DATE,
               b.SSBSECT_LEARNER_REGSTART_FDATE, --open learning first start date
               b.SSBSECT_LEARNER_REGSTART_TDATE, --open learning last start date
               b.SSBSECT_DUNT_CODE,
               b.SSBSECT_NUMBER_OF_UNITS,
               c.GTVDUNT_NUMBER_OF_DAYS --number of days for the duration unit code (e.g. 7 days in a week) 
        from szvstcr a
        
        --section table
        inner join ssbsect b
        on b.SSBSECT_TERM_CODE = a.SZVSTCR_TERM_CODE
        and b.SSBSECT_CRN = a.SZVSTCR_CRN
        
        --duration unit code validation table
        left outer join gtvdunt c
        on c.GTVDUNT_CODE = b.SSBSECT_DUNT_CODE
        
        where a.szvstcr_pidm = c_stuPidm
        and a.szvstcr_term_code > '202300'
        -- Request from Ashley Boyes Ticket # 2011193 and 2013893 Nov 13 2024 GM 
        -- Removing Regional colleges (RC) and Labs (LAB) from Courses list
        and (b.SSBSECT_INSM_CODE != 'RC'
         AND b.SSBSECT_SCHD_CODE != 'LAB')
        -- End change Nov 13 2024 GM
        ;
--        and szvstcr_term_code > '202001' --'202000' --'202001'
--        and szvstcr_term_code < '202003'; --'202100'; --'202003';

    getRegClasses_rec   getRegClasses_c%rowtype;
    
    
    --Cursor to determine if the new record is the same as the old record.
    cursor getSameRec_c (c_stuPidm number, c_studentID varchar2, c_uniqueCrseID varchar2, c_crseTitle varchar2,
            c_crseNum varchar2, c_statusDesc varchar2, c_termCode varchar2, c_instrEmail varchar2, c_instrEmail2 varchar2,
            c_instrEmail3 varchar2, c_instrEmail4 varchar2, c_instrEmail5 varchar2, c_instrEmail6 varchar2, c_instrEmail7 varchar2, 
            c_instrEmail8 varchar2, c_instrEmail9 varchar2, c_instrEmail10 varchar2, c_instrEmail11 varchar2, c_instrEmail12 varchar2, 
            c_instrEmail13 varchar2, c_instrEmail14 varchar2, c_instrEmail15 varchar2, c_instrEmail16 varchar2, c_instrEmail17 varchar2,
            c_instrEmail18 varchar2, c_instrEmail19 varchar2, c_instrEmail20 varchar2, c_crseDays varchar2, 
            c_startTime varchar2, c_endTime varchar2, c_startDate date, c_endDate date, c_enrollEndDate date, c_enrolled varchar2, 
            c_enrollDate date, c_gradeCode varchar2, c_gradeDate date, c_creditHrs number) is
        
        select 'S' inSZBSYMCSame
        from szbsymc
        where szbsymc_pidm = c_stuPidm
        and szbsymc_studentID = c_studentID
        and nvl(szbsymc_uniqcrseid,'~') = nvl(c_uniqueCrseID,'~')
        and nvl(szbsymc_crsetitle,'~') = nvl(c_crseTitle,'~')    
        and nvl(szbsymc_crsenum,'~') = nvl(c_crseNum,'~')    
        and nvl(szbsymc_status,'~') = nvl(c_statusDesc,'~')    
        and nvl(szbsymc_term,'~') = nvl(c_termCode,'~')    
        and nvl(szbsymc_instrEmail,'~') = nvl(c_instrEmail,'~')    
        and nvl(szbsymc_instrEmail2,'~') = nvl(c_instrEmail2,'~')    
        and nvl(szbsymc_instrEmail3,'~') = nvl(c_instrEmail3,'~')    
        and nvl(szbsymc_instrEmail4,'~') = nvl(c_instrEmail4,'~')    
        and nvl(szbsymc_instrEmail5,'~') = nvl(c_instrEmail5,'~')    
        and nvl(szbsymc_instrEmail6,'~') = nvl(c_instrEmail6,'~')
        and nvl(szbsymc_instrEmail7,'~') = nvl(c_instrEmail7,'~')
        and nvl(szbsymc_instrEmail8,'~') = nvl(c_instrEmail8,'~')
        and nvl(szbsymc_instrEmail9,'~') = nvl(c_instrEmail9,'~')
        and nvl(szbsymc_instrEmail10,'~') = nvl(c_instrEmail10,'~')
        and nvl(szbsymc_instrEmail11,'~') = nvl(c_instrEmail11,'~')
        and nvl(szbsymc_instrEmail12,'~') = nvl(c_instrEmail12,'~')
        and nvl(szbsymc_instrEmail13,'~') = nvl(c_instrEmail13,'~')
        and nvl(szbsymc_instrEmail14,'~') = nvl(c_instrEmail14,'~')
        and nvl(szbsymc_instrEmail15,'~') = nvl(c_instrEmail15,'~')
        and nvl(szbsymc_instrEmail16,'~') = nvl(c_instrEmail16,'~')
        and nvl(szbsymc_instrEmail17,'~') = nvl(c_instrEmail17,'~')
        and nvl(szbsymc_instrEmail18,'~') = nvl(c_instrEmail18,'~')
        and nvl(szbsymc_instrEmail19,'~') = nvl(c_instrEmail19,'~')
        and nvl(szbsymc_instrEmail20,'~') = nvl(c_instrEmail20,'~')
        and nvl(szbsymc_days,'~') = nvl(c_crseDays,'~')
        and nvl(szbsymc_starttime,'~') = nvl(c_startTime,'~')
        and nvl(szbsymc_endtime,'~') = nvl(c_endTime,'~')
        and to_date(nvl(to_char(szbsymc_startdate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_startDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsymc_enddate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_endDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and to_date(nvl(to_char(szbsymc_enrollenddate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_enrollEndDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsymc_enrolled,'~') = nvl(c_enrolled,'~')
        and to_date(nvl(to_char(szbsymc_enrolldate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_enrollDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
        and nvl(szbsymc_gradecode,'~') = nvl(c_gradeCode,'~')           
        and to_date(nvl(to_char(szbsymc_gradedate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_gradeDate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY')
--        and to_date(to_char(szbsymc_gradedate,'MM/DD/YYYY'),'MM/DD/YYYY') = to_date(to_char(c_gradeDate,'MM/DD/YYYY'),'MM/DD/YYYY')
        and szbsymc_credithrs = c_creditHrs;        
--        and nvl(szbsymc_,'~') = nvl(c_,'~');    
            
    getSameRec_rec      getSameRec_c%rowtype;
    
    
    --Cursor to retrieve all secondary instructors.
    cursor getSecInstr_c(c_termCode varchar2, c_crn varchar2) is
    
        select distinct a.sirasgn_pidm
        from sirasgn a where a.sirasgn_term_code = c_termCode
        and a.sirasgn_crn = c_crn
        --exclude the primary instructor from this list
        and not exists (select 1 from sirasgn b 
                where b.SIRASGN_TERM_CODE = a.SIRASGN_TERM_CODE 
                and b.SIRASGN_CRN = a.SIRASGN_CRN 
                and b.SIRASGN_PIDM = a.SIRASGN_PIDM
                and b.sirasgn_primary_ind = 'Y');
        
    getSecInstr_rec    getSecInstr_c%rowtype;
    
    
    --Cursor to retrieve all students who have registrations in the system.
    cursor getStudents_c is
        
        select szbsyms_pidm, szbsyms_studentID from szbsyms
        where szbsyms_rectype = 'REG'
--        and szbsyms_pidm in (10011451,10460103)
        union
        select szbsyms_pidm, szbsyms_studentID from szbsyms
        where szbsyms_rectype = 'APP$REG';
--        and szbsyms_pidm in (10011451,10460103);
    
    getStudents_rec     getStudents_c%rowtype;
    
    
    --Cursor to determine if a record needs to be updated.
    cursor getUpdate_c (c_stuPidm number, c_uniqueCrseID varchar2) is
        
        select 'U' inSZBSYMCUpdate
        from szbsymc
        where szbsymc_pidm = c_stuPidm
        and szbsymc_uniqcrseid = c_uniqueCrseID;
        
    getUpdate_rec       getUpdate_c%rowtype;
    
    
    
    --Function to determine the number of active internal email addresses an instructor has.
    function getEmailCnt_f(f_instPidm number) return number is
    
    BEGIN
        emailCnt := 0;
    
         /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
        select count(*) into emailCnt
        from goremal where goremal_pidm = f_instPidm
        and goremal_emal_code = 'IA'
        and goremal_status_ind = 'A';
        */
        Select count(*) into emailCnt
        from GOBTPAC where Gobtpac_pidm = f_instPidm;
        
        return emailCnt;
    
    END;
    
    
    
    --Procedure that retrieves the number of credit hours for a section.
    procedure getCreditHrs_p (p_termCode varchar2, p_crn varchar2) is
    
    BEGIN
        creditHrs := null;
        
        select szvsect_credit_hrs into creditHrs
        from szvsect where szvsect_term_code = p_termCode
        and szvsect_crn = p_crn;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getCreditHrs_p Exception - No Data Found';
            msg := 'TERM: ' || p_termCode || ' CRN: ' || p_crn || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getCreditHrs_p;
    
    
    --Procedure to retrieve a sections enrollment end date.
    procedure getEnrollEndDate_p (p_termCode varchar2, p_crn varchar2) is
    
    BEGIN
        enrollEndDate := null;
        
        select ssbsect_reg_to_date into enrollEndDate
        from ssbsect where ssbsect_term_code = p_termCode
        and ssbsect_crn = p_crn;
        
        enrollEndDate := to_date(to_char(enrollEndDate, 'MM/DD/YYYY'), 'MM/DD/YYYY');
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getEnrollEndDate_p Exception - No Data Found';
            msg := 'TERM: ' || p_termCode || ' CRN: ' || p_crn || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getEnrollEndDate_p;
     
    
    --Procedure to retrieve instructor email addresses.
    procedure getInstrEmail_p (p_termCode varchar2, p_crn varchar2) is
    
    BEGIN    
        instrPidm := null;
        instrPidm2 := null;
        instrPidm3 := null;
        instrPidm4 := null;
        instrPidm5 := null;
        instrPidm6 := null;
        instrPidm7 := null;
        instrPidm8 := null;
        instrPidm9 := null;
        instrPidm10 := null;
        instrPidm11 := null;
        instrPidm12 := null;
        instrPidm13 := null;
        instrPidm14 := null;
        instrPidm15 := null;
        instrPidm16 := null;
        instrPidm17 := null;
        instrPidm18 := null;
        instrPidm19 := null;
        instrPidm20 := null;
        instrEmail := null;
        instrEmail2 := null;
        instrEmail3 := null;
        instrEmail4 := null;
        instrEmail5 := null;
        instrEmail6 := null;
        instrEmail7 := null;
        instrEmail8 := null;
        instrEmail9 := null;
        instrEmail10 := null;
        instrEmail11 := null;
        instrEmail12 := null;
        instrEmail13 := null;
        instrEmail14 := null;
        instrEmail15 := null;
        instrEmail16 := null;
        instrEmail17 := null;
        instrEmail18 := null;
        instrEmail19 := null;
        instrEmail20 := null;
        getSecInstr_rec := null;
--        instrCnt := 0;
--        instrEmailCnt := 0;
        
--        select count(*) into instrCnt
--        from sirasgn where sirasgn_term_code = p_termCode
--        and sirasgn_crn = p_crn
--        and sirasgn_primary_ind = 'Y';
        
--        if instrCnt > 0 then
            --Retreive primary instructor pidm.
            select max(sirasgn_pidm) into instrPidm
            from sirasgn where sirasgn_term_code = p_termCode
            and sirasgn_crn = p_crn
            and sirasgn_primary_ind = 'Y';
            
            --If there is a primary instructor, retrieve email.
            if getEmailCnt_f(instrPidm) > 0 then
                /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
                select goremal_email_address into instrEmail
                from goremal where goremal_pidm = instrPidm
                and goremal_emal_code = 'IA'
                and goremal_status_ind = 'A';
                */
                Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail
                from GOBTPAC where Gobtpac_pidm = instrPidm;
            
            end if;
        
--        end if;
        
        --Retrieve secondary instructors.
        open getSecInstr_c(p_termCode, p_crn);
        loop
            fetch getSecInstr_c into getSecInstr_rec;
            exit when getSecInstr_c%notfound;
        
            if getSecInstr_c%rowcount = 1 then 
                instrPidm2 := getSecInstr_rec.sirasgn_pidm;
             
            elsif getSecInstr_c%rowcount = 2 then
                instrPidm3 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 3 then
                instrPidm4 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 4 then
                instrPidm5 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 5 then
                instrPidm6 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 6 then
                instrPidm7 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 7 then
                instrPidm8 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 8 then
                instrPidm9 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 9 then
                instrPidm10 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 10 then
                instrPidm11 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 11 then
                instrPidm12 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 12 then
                instrPidm13 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 13 then
                instrPidm14 := getSecInstr_rec.sirasgn_pidm;
                
            elsif getSecInstr_c%rowcount = 14 then
                instrPidm15 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 15 then
                instrPidm16 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 16 then
                instrPidm17 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 17 then
                instrPidm18 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 18 then
                instrPidm19 := getSecInstr_rec.sirasgn_pidm;
            
            elsif getSecInstr_c%rowcount = 19 then
                instrPidm20 := getSecInstr_rec.sirasgn_pidm;
            
            end if;
        
        end loop;
        close getSecInstr_c;
        
        --Retrieve secondary instructor email addresses.
        if instrPidm2 is not null AND getEmailCnt_f(instrPidm2) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail2
            from goremal where goremal_pidm = instrPidm2
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail2
            from GOBTPAC where Gobtpac_pidm = instrPidm2;

        end if;
        
        if instrPidm3 is not null AND getEmailCnt_f(instrPidm3) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail3
            from goremal where goremal_pidm = instrPidm3
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail3
            from GOBTPAC where Gobtpac_pidm = instrPidm3;
            
        end if;
        
        if instrPidm4 is not null AND getEmailCnt_f(instrPidm4) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail4
            from goremal where goremal_pidm = instrPidm4
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail4
            from GOBTPAC where Gobtpac_pidm = instrPidm4;
        
        end if;
        
        if instrPidm5 is not null AND getEmailCnt_f(instrPidm5) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail5
            from goremal where goremal_pidm = instrPidm5
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail5
            from GOBTPAC where Gobtpac_pidm = instrPidm5;
        
        end if;
        
        if instrPidm6 is not null AND getEmailCnt_f(instrPidm6) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail6
            from goremal where goremal_pidm = instrPidm6
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail6
            from GOBTPAC where Gobtpac_pidm = instrPidm6;
        
        end if;
        
        if instrPidm7 is not null AND getEmailCnt_f(instrPidm7) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail7
            from goremal where goremal_pidm = instrPidm7
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail7
            from GOBTPAC where Gobtpac_pidm = instrPidm7;
        
        end if;
        
        if instrPidm8 is not null AND getEmailCnt_f(instrPidm8) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail8
            from goremal where goremal_pidm = instrPidm8
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail8
            from GOBTPAC where Gobtpac_pidm = instrPidm8;
        
        end if;
        
        if instrPidm9 is not null AND getEmailCnt_f(instrPidm9) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail9
            from goremal where goremal_pidm = instrPidm9
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail9
            from GOBTPAC where Gobtpac_pidm = instrPidm9;
        
        end if;
        
        if instrPidm10 is not null AND getEmailCnt_f(instrPidm10) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail10
            from goremal where goremal_pidm = instrPidm10
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail10
            from GOBTPAC where Gobtpac_pidm = instrPidm10;
        
        end if;
        
        if instrPidm11 is not null AND getEmailCnt_f(instrPidm11) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail11
            from goremal where goremal_pidm = instrPidm11
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail11
            from GOBTPAC where Gobtpac_pidm = instrPidm11;
            
        end if;
        
        if instrPidm12 is not null AND getEmailCnt_f(instrPidm12) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail12
            from goremal where goremal_pidm = instrPidm12
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail12
            from GOBTPAC where Gobtpac_pidm = instrPidm12;
        
        end if;
        
        if instrPidm13 is not null AND getEmailCnt_f(instrPidm13) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail13
            from goremal where goremal_pidm = instrPidm13
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail13
            from GOBTPAC where Gobtpac_pidm = instrPidm13;
        
        end if;
        
        if instrPidm14 is not null AND getEmailCnt_f(instrPidm14) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail14
            from goremal where goremal_pidm = instrPidm14
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail14
            from GOBTPAC where Gobtpac_pidm = instrPidm14;

        end if;
        
        if instrPidm15 is not null AND getEmailCnt_f(instrPidm15) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail15
            from goremal where goremal_pidm = instrPidm15
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail15
            from GOBTPAC where Gobtpac_pidm = instrPidm15;

        end if;
        
        if instrPidm16 is not null AND getEmailCnt_f(instrPidm16) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail16
            from goremal where goremal_pidm = instrPidm16
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail16
            from GOBTPAC where Gobtpac_pidm = instrPidm16;

        end if;
        
        if instrPidm17 is not null AND getEmailCnt_f(instrPidm17) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail17
            from goremal where goremal_pidm = instrPidm17
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail17
            from GOBTPAC where Gobtpac_pidm = instrPidm17;

        end if;
        
        if instrPidm18 is not null AND getEmailCnt_f(instrPidm18) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail18
            from goremal where goremal_pidm = instrPidm18
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail18
            from GOBTPAC where Gobtpac_pidm = instrPidm18;

        end if;
        
        if instrPidm19 is not null AND getEmailCnt_f(instrPidm19) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail19
            from goremal where goremal_pidm = instrPidm19
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail19
            from GOBTPAC where Gobtpac_pidm = instrPidm19;

        end if;
        
        if instrPidm20 is not null AND getEmailCnt_f(instrPidm20) > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
            select goremal_email_address into instrEmail20
            from goremal where goremal_pidm = instrPidm20
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into instrEmail20
            from GOBTPAC where Gobtpac_pidm = instrPidm20;

        end if;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getInstr_p Exception - No Data Found';
            msg := 'TERMCODE: ' || p_termCode || ' CRN: ' || p_crn || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN
            subjct := 'symplicityClassDataLoad.getInstr_p Exception - Too Many Rows';
            msg := 'TERMCODE: ' || p_termCode || ' CRN: ' || p_crn || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
    
    END getInstrEmail_p;
       
    
    --Procedure to retrieve section meeting times.
    procedure getMeetTimes_p (p_termCode varchar2, p_crn varchar2) is
    
    BEGIN
--        crseMon := null;
--        crseTue := null;
--        crseWed := null;
--        crseThu := null;
--        crseFri := null;
--        crseSat := null;
--        crseSun := null;
        crseDays := null;
        startTime := null;
        endTime := null;
        
        open getMeetTimes_c(p_termCode, p_crn);
        fetch getMeetTimes_c into getMeetTimes_rec;
        
--        crseMon := getMeetTimes_rec.ssrmeet_mon_day;
--        crseTue := getMeetTimes_rec.ssrmeet_tue_day;
--        crseWed := getMeetTimes_rec.ssrmeet_wed_day;
--        crseThu := getMeetTimes_rec.ssrmeet_thu_day;
--        crseFri := getMeetTimes_rec.ssrmeet_fri_day;
--        crseSat := getMeetTimes_rec.ssrmeet_sat_day;
--        crseSun := getMeetTimes_rec.ssrmeet_sun_day;
        crseDays := getMeetTimes_rec.ssrmeet_mon_day || getMeetTimes_rec.ssrmeet_tue_day || getMeetTimes_rec.ssrmeet_wed_day || getMeetTimes_rec.ssrmeet_thu_day ||
                        getMeetTimes_rec.ssrmeet_fri_day || getMeetTimes_rec.ssrmeet_sat_day || getMeetTimes_rec.ssrmeet_sun_day;
        startTime := getMeetTimes_rec.ssrmeet_begin_time;
        endTime := getMeetTimes_rec.ssrmeet_end_time;
        
        close getMeetTimes_c;
        
 
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getMeetTimes_p Exception - No Data Found';
            msg := 'TERM: ' || p_termCode || ' CRN: ' || p_crn || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getMeetTimes_p;


    --Procedure to compare and determine if records are the same and whether to insert or update them.
    procedure getSameRec_p(p_stuPidm number, p_studentID varchar2, p_uniqueCrseID varchar2, p_crseTitle varchar2,
            p_crseNum varchar2, p_statusDesc varchar2, p_termCode varchar2, p_instrEmail varchar2, p_instrEmail2 varchar2,
            p_instrEmail3 varchar2, p_instrEmail4 varchar2, p_instrEmail5 varchar2, p_instrEmail6 varchar2, p_instrEmail7 varchar2, 
            p_instrEmail8 varchar2, p_instrEmail9 varchar2, p_instrEmail10 varchar2, p_instrEmail11 varchar2, p_instrEmail12 varchar2, 
            p_instrEmail13 varchar2, p_instrEmail14 varchar2, p_instrEmail15 varchar2, p_instrEmail16 varchar2, p_instrEmail17 varchar2,
            p_instrEmail18 varchar2, p_instrEmail19 varchar2, p_instrEmail20 varchar2, p_crseDays varchar2, 
            p_startTime varchar2, p_endTime varchar2, p_startDate date, p_endDate date, p_enrollEndDate date, p_enrolled varchar2, 
            p_enrollDate date, p_gradeCode varchar2, p_gradeDate date, p_creditHrs number) is
    
    BEGIN
        toInsertUpdate := 'Y';
        getSameRec_rec := null;
        
        open getSameRec_c(p_stuPidm, p_studentID, p_uniqueCrseID, p_crseTitle, p_crseNum,
                            p_statusDesc, p_termCode, p_instrEmail, p_instrEmail2, p_instrEmail3,
                            p_instrEmail4, p_instrEmail5, p_instrEmail6, p_instrEmail7, p_instrEmail8,
                            p_instrEmail9, p_instrEmail10, p_instrEmail11, p_instrEmail12, p_instrEmail13,
                            p_instrEmail14, p_instrEmail15, p_instrEmail16, p_instrEmail17, p_instrEmail18,
                            p_instrEmail19, p_instrEmail20,  p_crseDays,  p_startTime, p_endTime, p_startDate,
                            p_endDate, p_enrollEndDate, p_enrolled, p_enrollDate,  p_gradeCode, p_gradeDate, p_creditHrs);
        fetch getSameRec_c into getSameRec_rec;
        
        if getSameRec_rec.inSZBSYMCSame = 'S' then
            toInsertUpdate := 'N';
            
        end if;
        
        close getSameRec_c;
    

    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getSameRec_p Exception - No Data Found';
            msg := 'TERM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
    
    END getSameRec_p;


    --Procedure to determine if a record should be updated.
    procedure getUpdate_p(p_stuPidm number, p_uniqueCrseID varchar2) is
    
    BEGIN
        toUpdate := 'N';
        getUpdate_rec := null;
        
        open getUpdate_c(p_stuPidm, p_uniqueCrseID);
        fetch getUpdate_c into getUpdate_rec;
               
        if getUpdate_rec.inSZBSYMCUpdate = 'U' then
            toUpdate := 'Y';
            
        end if;
        
        close getUpdate_c;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityClassDataLoad.getUpdate_p Exception - No Data Found';
            msg := 'PIDM: ' || p_stuPidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityClassDataLoad.getUpdate_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;

    END getUpdate_p;    
    
    
    --Procedure that inserts new records into SZBSYMC.
    procedure insert_szbsymc_p(p_stuPidm number, p_studentID varchar2, p_uniqueCrseID varchar2, p_crseTitle varchar2,
            p_crseNum varchar2, p_statusDesc varchar2, p_termCode varchar2, p_instrEmail varchar2, p_instrEmail2 varchar2,
            p_instrEmail3 varchar2, p_instrEmail4 varchar2, p_instrEmail5 varchar2, p_instrEmail6 varchar2, p_instrEmail7 varchar2, 
            p_instrEmail8 varchar2, p_instrEmail9 varchar2, p_instrEmail10 varchar2, p_instrEmail11 varchar2, p_instrEmail12 varchar2, 
            p_instrEmail13 varchar2, p_instrEmail14 varchar2, p_instrEmail15 varchar2, p_instrEmail16 varchar2, p_instrEmail17 varchar2,
            p_instrEmail18 varchar2, p_instrEmail19 varchar2, p_instrEmail20 varchar2, p_crseDays varchar2, 
            p_startTime varchar2, p_endTime varchar2, p_startDate date, p_endDate date, p_enrollEndDate date, p_enrolled varchar2, 
            p_enrollDate date, p_gradeCode varchar2, p_gradeDate date, p_creditHrs number) is

    BEGIN
        INSERT INTO saturn.SZBSYMC
        (
            SZBSYMC_PIDM,
            SZBSYMC_STUDENTID,
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
            SZBSYMC_CREDITHRS,
            SZBSYMC_ADDDATE,
            SZBSYMC_ACTIVITYDATE
--            SZBSYMC_
        )
        VALUES
        (
            p_stuPidm,
            p_studentID,
            p_uniqueCrseID,
            p_crseTitle,
            p_crseNum,
            p_statusDesc,
            p_termCode,
            p_instrEmail,
            p_instrEmail2,
            p_instrEmail3,
            p_instrEmail4,
            p_instrEmail5,
            p_instrEmail6,
            p_instrEmail7,
            p_instrEmail8,
            p_instrEmail9,
            p_instrEmail10,
            p_instrEmail11,
            p_instrEmail12,
            p_instrEmail13,
            p_instrEmail14,
            p_instrEmail15,
            p_instrEmail16,
            p_instrEmail17,
            p_instrEmail18,
            p_instrEmail19,
            p_instrEmail20,
            p_crseDays,
            p_startTime,
            p_endTime,
            p_startDate,
            p_endDate,
            p_enrollEndDate,
            p_enrolled,
            p_enrollDate,
            p_gradeCode,
            p_gradeDate,
            p_creditHrs,
            sysdate,
            sysdate
        );

    END insert_SZBSYMC_p;
    
    
    --Procedure that inserts old records into the history/repeating table SZRSYMC.
    procedure insert_szrsymc_p (p_stuPidm number, p_uniqueCrseID varchar2) is
    
    BEGIN
               
        getExistingRec_rec := null;
        
        open getExistingRec_c(p_stuPidm, p_uniqueCrseID);
        fetch getExistingRec_c into getExistingRec_rec;
        
        INSERT INTO saturn.szrsymc
        (
            szrsymc_PIDM,
            szrsymc_STUDENTID,
            szrsymc_UNIQCRSEID,
            szrsymc_CRSETITLE,
            szrsymc_CRSENUM,
            szrsymc_STATUS,
            szrsymc_TERM,
            szrsymc_INSTREMAIL,
            szrsymc_INSTREMAIL2,
            szrsymc_INSTREMAIL3,
            szrsymc_INSTREMAIL4,
            szrsymc_INSTREMAIL5,
            szrsymc_INSTREMAIL6,
            szrsymc_INSTREMAIL7,
            szrsymc_INSTREMAIL8,
            szrsymc_INSTREMAIL9,
            szrsymc_INSTREMAIL10,
            szrsymc_INSTREMAIL11,
            szrsymc_INSTREMAIL12,
            szrsymc_INSTREMAIL13,
            szrsymc_INSTREMAIL14,
            szrsymc_INSTREMAIL15,
            szrsymc_INSTREMAIL16,
            szrsymc_INSTREMAIL17,
            szrsymc_INSTREMAIL18,
            szrsymc_INSTREMAIL19,
            szrsymc_INSTREMAIL20,
            szrsymc_DAYS,
            szrsymc_STARTTIME,
            szrsymc_ENDTIME,
            szrsymc_STARTDATE,
            szrsymc_ENDDATE,
            szrsymc_ENROLLENDDATE,
            szrsymc_ENROLLED,
            szrsymc_ENROLLDATE,
            szrsymc_GRADECODE,
            szrsymc_GRADEDATE,
            szrsymc_CREDITHRS,
            szrsymc_SZRADDDATE,
            szrsymc_SZRACTIVITYDATE
--            szrsymc_
        )
        VALUES
        (
            getExistingRec_rec.szbsymc_pidm,
            getExistingRec_rec.szbsymc_studentID,
            getExistingRec_rec.szbsymc_uniqCrseID,
            getExistingRec_rec.szbsymc_crseTitle,
            getExistingRec_rec.szbsymc_crseNum,
            getExistingRec_rec.szbsymc_status,
            getExistingRec_rec.szbsymc_term,
            getExistingRec_rec.szbsymc_instrEmail,
            getExistingRec_rec.szbsymc_instrEmail2,
            getExistingRec_rec.szbsymc_instrEmail3,
            getExistingRec_rec.szbsymc_instrEmail4,
            getExistingRec_rec.szbsymc_instrEmail5,
            getExistingRec_rec.szbsymc_instrEmail6,
            getExistingRec_rec.szbsymc_instrEmail7,
            getExistingRec_rec.szbsymc_instrEmail8,
            getExistingRec_rec.szbsymc_instrEmail9,
            getExistingRec_rec.szbsymc_instrEmail10,
            getExistingRec_rec.szbsymc_instrEmail11,
            getExistingRec_rec.szbsymc_instrEmail12,
            getExistingRec_rec.szbsymc_instrEmail13,
            getExistingRec_rec.szbsymc_instrEmail14,
            getExistingRec_rec.szbsymc_instrEmail15,
            getExistingRec_rec.szbsymc_instrEmail16,
            getExistingRec_rec.szbsymc_instrEmail17,
            getExistingRec_rec.szbsymc_instrEmail18,
            getExistingRec_rec.szbsymc_instrEmail19,
            getExistingRec_rec.szbsymc_instrEmail20,
            getExistingRec_rec.szbsymc_days,
            getExistingRec_rec.szbsymc_startTime,
            getExistingRec_rec.szbsymc_endTime,
            getExistingRec_rec.szbsymc_startDate,
            getExistingRec_rec.szbsymc_endDate,
            getExistingRec_rec.szbsymc_enrollEndDate,
            getExistingRec_rec.szbsymc_enrolled,
            getExistingRec_rec.szbsymc_enrollDate,
            getExistingRec_rec.szbsymc_gradeCode,
            getExistingRec_rec.szbsymc_gradeDate,
            getExistingRec_rec.szbsymc_creditHrs,
            sysdate,
            sysdate
        );
        
        close getExistingRec_c;
    
    END insert_szrsymc_p;



BEGIN
    -- Adding code to set the ENROLLED flag to N for any students courses no  
        -- longer in the active enrolment list Jan 24, 2022 GM 

        UPDATE SZBSYMC CT SET CT.SZBSYMC_ENROLLED = 'N', CT.SZBSYMC_ACTIVITYDATE = systimestamp 
         WHERE NOT EXISTS (SELECT 'Y' FROM SATURN.SZVSTCR C 
                           WHERE C.SZVSTCR_PIDM = CT.SZBSYMC_PIDM 
                            and C.SZVSTCR_TERM_CODE = CT.SZBSYMC_TERM 
                            and C.SZVSTCR_CRN = substr(CT.SZBSYMC_UNIQCRSEID,instr(CT.SZBSYMC_UNIQCRSEID,'_',1,2)+1)
                            -- Adding this section to remove Regional College and LAB courses from the integration
                             -- Tickets 2011193 and 2013893
                             -- G Mclellan Nov 13, 2024
                             AND ((Select MAX(S.SSBSECT_INSM_CODE) from SATURN.SSBSECT S
                                   WHERE S.SSBSECT_TERM_CODE = CT.SZBSYMC_TERM
                                     AND S.SSBSECT_CRN = substr(CT.SZBSYMC_UNIQCRSEID,instr(CT.SZBSYMC_UNIQCRSEID,'_',1,2)+1)) != 'RC'
                             AND (Select MAX(S.SSBSECT_SCHD_CODE) from SATURN.SSBSECT S
                                  WHERE S.SSBSECT_TERM_CODE = CT.SZBSYMC_TERM
                                    AND S.SSBSECT_CRN = substr(CT.SZBSYMC_UNIQCRSEID,instr(CT.SZBSYMC_UNIQCRSEID,'_',1,2)+1)) != 'LAB'    )
                            -- End addition G Mclellan Nov 13, 2024
                            ) 
         AND CT.SZBSYMC_ENROLLED = 'Y'; 
        Commit; 
        -- End mod GM 
    
    --Retrieve list of students with registrations.
    open getStudents_c;
    
    loop
        fetch getStudents_c into getStudents_rec;
        exit when getStudents_c%notfound;
        
        stuPidm := null;
        studentID := null;
        getRegClasses_rec := null;
        
        stuPidm := getStudents_rec.szbsyms_pidm;
        studentID := getStudents_rec.szbsyms_studentID;
        
        --Retreive list of classes the student is registered in.
        open getRegClasses_c(stuPidm);
        loop
            fetch getRegClasses_c into getRegClasses_rec;
            exit when getRegClasses_c%notfound;
            
            uniqueCrseID := null;
            crseTitle := null;
            crseNum := null;
            status := null;
            statusDesc := null;
            termCode := null;
            startDate := null;
            endDate := null;
            enrolled := null;
            enrollDate := null;
            gradeCode := null;
            gradeDate := null;
            l_stvrstsInclSectEnrl := null; --INC0141120 NTOURNEY 30-AUG-2022
            
            --Retrieve/generated unique course ID, title, number and status.
            uniqueCrseID := getRegClasses_rec.szvstcr_subj_code || getRegClasses_rec.szvstcr_crse_numb ||
                                '_' || getRegClasses_rec.szvstcr_term_code || '_' || getRegClasses_rec.szvstcr_crn;
            crseTitle := getRegClasses_rec.szvstcr_crse_title || ' (' || getRegClasses_rec.szvstcr_subj_code || '-' || getRegClasses_rec.szvstcr_crse_numb || '-' ||
                                getRegClasses_rec.szvstcr_seq_numb || ' - ' || getRegClasses_rec.szvstcr_crn || '.' || getRegClasses_rec.szvstcr_term_code || ')';
            --crseTitle := getRegClasses_rec.szvstcr_crse_title; - Updated to the above on 7 OCT 2021 by PL - INC0102671 - FP RFC 561130.
            crseNum := getRegClasses_rec.szvstcr_subj_code || getRegClasses_rec.szvstcr_crse_numb;
            status := getRegClasses_rec.szvstcr_rsts_code;   --stvrsts
            
            --Retreive status description.
            if status is not null then
                select stvrsts_desc,
                       STVRSTS_INCL_SECT_ENRL --INC0141120 NTOURNEY 30-AUG-2022
                  into statusDesc,
                       l_stvrstsInclSectEnrl --INC0141120 NTOURNEY 30-AUG-2022
                from stvrsts where stvrsts_code = status;
            
            end if; 
            
            --Retreive term code, start and end dates.
            termCode := getRegClasses_rec.szvstcr_term_code; 
            
            --NTOURNEY RFC561933 04-JUL-2023 - Changed course start/end dates to pull from SSBSECT.
            --If "part of term" is defined, use the part of term start/end dates.
            if (getRegClasses_rec.SSBSECT_PTRM_CODE is not null) then
                startDate := to_date(to_char(getRegClasses_rec.SSBSECT_PTRM_START_DATE, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                endDate := to_date(to_char(getRegClasses_rec.SSBSECT_PTRM_END_DATE, 'MM/DD/YYYY'), 'MM/DD/YYYY');
            
            --If "part of term" is null, use open learning dates, and add the duration to the end date.
            --Calculate the duration in days by multiplying the number of units by number of days for that unit
            --(e.g. 5 weeks = 5x7 = 35 days).
            else
                startDate := to_date(to_char(getRegClasses_rec.SSBSECT_LEARNER_REGSTART_FDATE, 'MM/DD/YYYY'), 'MM/DD/YYYY');
                endDate := to_date(to_char(getRegClasses_rec.SSBSECT_LEARNER_REGSTART_TDATE + 
                    (getRegClasses_rec.SSBSECT_NUMBER_OF_UNITS * getRegClasses_rec.GTVDUNT_NUMBER_OF_DAYS), 'MM/DD/YYYY'), 'MM/DD/YYYY');
            end if;
            
            getEnrollEndDate_p(getRegClasses_rec.szvstcr_term_code, getRegClasses_rec.szvstcr_crn);
            
            --Set enrollment status.
            --if status in ('8R','AU','CH','EX','PL','RC','RE','RW','TR') then
            if l_stvrstsInclSectEnrl = 'Y' then --INC0141120 NTOURNEY 30-AUG-2022
                
                enrolled := 'Y';
                
            else
                
                enrolled := 'N';
            
            end if;
            
            --Retreive remaining details
            enrollDate := to_date(to_char(getRegClasses_rec.szvstcr_rsts_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
            gradeCode := getRegClasses_rec.szvstcr_grde_code;
            gradeDate := to_date(to_char(getRegClasses_rec.szvstcr_grde_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
            
            getCreditHrs_p(getRegClasses_rec.szvstcr_term_code, getRegClasses_rec.szvstcr_crn);
            
            getMeetTimes_p(getRegClasses_rec.szvstcr_term_code, getRegClasses_rec.szvstcr_crn);
            
            getInstrEmail_p(getRegClasses_rec.szvstcr_term_code, getRegClasses_rec.szvstcr_crn);
            
--            DBMS_OUTPUT.PUT_LINE(stuPidm || ', ' || studentID || ', ' || uniqueCrseID || ', ' || crseTitle || ', ' ||
--            crseNum || ', ' || statusDesc || ', ' || termCode || ', ' || instrEmail || ', ' || crseDays || ', ' || startTime || ', ' || endTime || ', ' || startDate || ', ' || 
--            endDate || ', ' || enrollEndDate || ', ' || enrolled || ', ' || enrollDate || ', ' || gradeCode || ', ' || gradeDate || ', ' || creditHrs ||', EOR');
            
            --Check if the same class record for a student already exists in SZBSYMC.
            getSameRec_p(stuPidm, studentID, uniqueCrseID, crseTitle, crseNum, statusDesc, termCode, instrEmail, instrEmail2, instrEmail3,
                                instrEmail4, instrEmail5, instrEmail6, instrEmail7, instrEmail8, instrEmail9, instrEmail10, instrEmail11, instrEmail12,
                                instrEmail13, instrEmail14, instrEmail15, instrEmail16, instrEmail17, instrEmail18, instrEmail19, instrEmail20, 
                                crseDays, startTime, endTime, startDate, endDate, enrollEndDate, enrolled, enrollDate, gradeCode, gradeDate, creditHrs);
            
            --If the same class record doesn't exist, it'll need to be inserted or updated in SZBSYMC.            
            if toInsertUpdate = 'Y' then
                --Determine if an update is needed.
                getUpdate_p(stuPidm, uniqueCrseID);
                
                --If the class record exists but is not the same as the new class record, an update is needed.
                if toUpdate = 'Y' then
                    
                    --Insert the old record into the history/repeating table SZRSYMC.
                    insert_szrsymc_p (stuPidm, uniqueCrseID);
                    
                    --Perform update.
                    UPDATE SZBSYMC
                    SET SZBSYMC_STUDENTID = studentID,
                        SZBSYMC_CRSETITLE = crseTitle,
                        SZBSYMC_CRSENUM = crseNum,
                        SZBSYMC_STATUS = statusDesc,
                        SZBSYMC_TERM = termCode,
                        SZBSYMC_INSTREMAIL = instrEmail,
                        SZBSYMC_INSTREMAIL2 = instrEmail2,
                        SZBSYMC_INSTREMAIL3 = instrEmail3,
                        SZBSYMC_INSTREMAIL4 = instrEmail4,
                        SZBSYMC_INSTREMAIL5 = instrEmail5,
                        SZBSYMC_INSTREMAIL6 = instrEmail6,
                        SZBSYMC_INSTREMAIL7 = instrEmail7,
                        SZBSYMC_INSTREMAIL8 = instrEmail8,
                        SZBSYMC_INSTREMAIL9 = instrEmail9,
                        SZBSYMC_INSTREMAIL10 = instrEmail10,
                        SZBSYMC_INSTREMAIL11 = instrEmail11,
                        SZBSYMC_INSTREMAIL12 = instrEmail12,
                        SZBSYMC_INSTREMAIL13 = instrEmail13,
                        SZBSYMC_INSTREMAIL14 = instrEmail14,
                        SZBSYMC_INSTREMAIL15 = instrEmail15,
                        SZBSYMC_INSTREMAIL16 = instrEmail16,
                        SZBSYMC_INSTREMAIL17 = instrEmail17,
                        SZBSYMC_INSTREMAIL18 = instrEmail18,
                        SZBSYMC_INSTREMAIL19 = instrEmail19,
                        SZBSYMC_INSTREMAIL20 = instrEmail20,
                        SZBSYMC_DAYS = crseDays,
                        SZBSYMC_STARTTIME = startTime,
                        SZBSYMC_ENDTIME = endTime,
                        SZBSYMC_STARTDATE = startDate,
                        SZBSYMC_ENDDATE = endDate,
                        SZBSYMC_ENROLLENDDATE = enrollEndDate,
                        SZBSYMC_ENROLLED = enrolled,
                        SZBSYMC_ENROLLDATE = enrollDate,
                        SZBSYMC_GRADECODE = gradeCode,
                        SZBSYMC_GRADEDATE = gradeDate,
                        SZBSYMC_CREDITHRS = creditHrs,
                        SZBSYMC_ACTIVITYDATE = sysdate         
                    WHERE SZBSYMC_PIDM = stuPidm
                    and SZBSYMC_UNIQCRSEID = uniqueCrseID;
                
                --Else the record is new, so insert it into SZBSYMC.
                else
                    insert_szbsymc_p(stuPidm, studentID, uniqueCrseID, crseTitle, crseNum, statusDesc, termCode, instrEmail, instrEmail2, instrEmail3,
                                        instrEmail4, instrEmail5, instrEmail6, instrEmail7, instrEmail8, instrEmail9, instrEmail10, instrEmail11, instrEmail12,
                                        instrEmail13, instrEmail14, instrEmail15, instrEmail16, instrEmail17, instrEmail18, instrEmail19, instrEmail20, 
                                        crseDays, startTime, endTime, startDate, endDate, enrollEndDate, enrolled, enrollDate, gradeCode, gradeDate, creditHrs);
                                        
                end if;
                                
            end if;
        
        end loop;
        
        close getRegClasses_c;
        
    end loop;
    
    close getStudents_c;
    
    COMMIT;


EXCEPTION
    WHEN OTHERS THEN
        rollback;
        subjct := 'symplicityClassDataLoad Exception';
        msg := 'PIDM: ' || stuPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;


END symplicityClassDataLoad;
/
