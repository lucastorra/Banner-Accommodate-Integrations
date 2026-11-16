CREATE OR REPLACE PROCEDURE BANINST1.symplicityFacultyDataLoad is

/******************************************************************************
   NAME:       symplicityFacultyDataLoad
   PURPOSE:    Symplicity Accommodate Faculty Data Load
               This procedure pulls student data from various Banner tables and loads it into the SZBSYMF table

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        ??-???-2021 Patrick Lo       	Initial creation
											
   1.1		  09-MAY-2023 Nigel Tourney		RFC 561854 - Increase minimum academic term from 202100 to 202200
   
   1.2        06-NOV-2025 Nigel Tourney     RFC 562894 - Increase minimum academic term from 202300 to 202400
   
   1.3        16-NOV-2025 Lucas Torra       ticket 3875078 - Increase minimum academic term from 202400 to 202500       
											
******************************************************************************/

    --Variable declarations.
    facPidm             number(8);

    --Required data
    facultyID           varchar2(9);   --spriden
    userName            varchar2(46);  --gobtpac 
    firstName           varchar2(60);
    lastName            varchar2(60);
    fullName            varchar2(120);
    middleName          varchar2(60);
    facEmail            varchar2(128);  --goremal
    
    
    phone               varchar2(18);  --sprtele
    facType             varchar2(30);
    fPTime              varchar2(10);
    facInd              varchar2(1);
    advInd              varchar2(1);
    progDesc            varchar2(75);
    schoolCode          varchar2(6);
    schoolDesc          varchar2(150);
    campus              varchar2(75);
    startDate           date;
    
    
    toInsertUpdate      varchar2(1);
    toUpdate            varchar2(1);
--    emailCnt            number(2);
--    phoneCnt            number(2);
    
    
    --Exception email
    l_status        varchar2(20);
    frm_add         varchar2(128);
    to_add          varchar2(128) := 'JProgramAnalyst@saskpolytech.ca';
    cc_add          varchar2(128):= 'lop@saskpolytech.ca';
    subjct          varchar2(150);
    msg             varchar2(10000);
    
    
    
    --Cursor that retrieves all instructors with assignments.
    cursor getAsgnPidm_c is
        
        select distinct sirasgn_pidm
        from sirasgn where sirasgn_term_code > '202500';
--        select distinct sirasgn_pidm
--        from sirasgn where sirasgn_term_code > '202001' --'202000'
--        and sirasgn_term_code < '202003'; --'202100';      
        
    getAsgnPidm_rec    getAsgnPidm_c%rowtype;
    
    
    --Cursor that retrieves an existing instructor record from SZBSYMF.
    cursor getExistingRec_c (c_pidm number) is
        
        select * from szbsymf
        where szbsymf_pidm = c_pidm;
    
    getExistingRec_rec        getExistingRec_c%rowtype;
    
    
    --Cursor that retrieves an instructors basic information.
    cursor getFacultyDetails_c (c_pidm number) is 
       
        select spriden_id,
               spriden_first_name,
               spriden_last_name,
               spriden_mi
        from SPRIDEN where spriden_pidm = c_pidm
        and spriden_change_ind is null;
    
    getFacultyDetails_rec    getFacultyDetails_c%rowtype;
    
    
    --Cursor that retreives an instructors type and status.
    cursor getInst_c (c_pidm number) is
        
        select sibinst_fcst_code,
               sibinst_fcst_date,
               sibinst_schd_ind,
               sibinst_advr_ind
        from sibinst where sibinst_pidm = c_pidm;
    
    getInst_rec     getInst_c%rowtype;
    
    
    --Cursor that retrieves the location of a program.
    cursor getProgramLocn_c (c_pidm number) is
        
        select spraddr_street_line1,
               spraddr_street_line2,
               spraddr_street_line3
        from SPRADDR where spraddr_pidm = c_pidm
        and spraddr_atyp_code = 'IA'
        and spraddr_status_ind is null
        and spraddr_to_date is null;
    
    getProgramLocn_rec    getProgramLocn_c%rowtype;
    
    
    --Cursor that determines if a new record is the same as an existing old record.
    cursor getSameRec_c (c_facPidm number, c_facultyID varchar2, c_userName varchar2, c_fName varchar2, c_lName varchar2, c_fullName varchar2, 
                        c_mName varchar2, c_facEmail varchar2, c_phone varchar2, c_facType varchar2, c_progDesc varchar2, c_school varchar2, c_campus varchar2, 
                        c_startDate date) is
        
        select 'S' inSZBSYMFSame
        from szbsymf
        where szbsymf_pidm = c_facPidm
        and szbsymf_facultyid = c_facultyID
        and szbsymf_username = c_userName
        and nvl(szbsymf_firstname,'~') = nvl(c_fName,'~') 
        and nvl(szbsymf_lastname,'~') = nvl(c_lName,'~')
        and nvl(szbsymf_fullname,'~') = nvl(c_fullName,'~')        
        and nvl(szbsymf_middlename,'~') = nvl(c_mName,'~')
        and nvl(szbsymf_email,'~') = nvl(c_facEmail,'~')
        and nvl(szbsymf_phone,'~') = nvl(c_phone,'~')
        and nvl(szbsymf_factype,'~') = nvl(c_facType,'~')
        and nvl(szbsymf_progdesc,'~') = nvl(c_progDesc,'~')
        and nvl(szbsymf_school,'~') = nvl(c_school,'~')
        and nvl(szbsymf_campus,'~') = nvl(c_campus,'~')
        and to_date(nvl(to_char(szbsymf_startdate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY') = to_date(nvl(to_char(c_startdate,'MM/DD/YYYY'),'01/01/1900'),'MM/DD/YYYY');
--        and to_date(to_char(szbsymf_startdate,'MM/DD/YYYY'),'MM/DD/YYYY') = to_date(to_char(c_startdate,'MM/DD/YYYY'),'MM/DD/YYYY');
--        and nvl(szbsymf_,'~') = nvl(c_,'~')

    getSameRec_rec       getSameRec_c%rowtype;
    
    
    --Cursor that determines if a record is to be updated.
    cursor getUpdate_c (c_facPidm number) is
        
        select 'U' inSZBSYMFUpdate
        from szbsymf
        where szbsymf_pidm = c_facPidm;
        
    getUpdate_rec       getUpdate_c%rowtype;
    
    
    
    --Procedure that retrieves an instructors contact information.
    procedure getFacultyContact_p (p_pidm number) is
    
    BEGIN
        facEmail := null;
        phone := null;
--        emailCnt := 0;
--        phoneCnt := 0;
        
--        select count(*) into emailCnt
--        from goremal where goremal_pidm = p_pidm
--        and goremal_emal_code = 'IA'
--        and goremal_status_ind = 'A';
        
--        if emailCnt > 0 then
            /* Removing because it is retreiving the wrong email for SSO GM Mar 2022
             select max(goremal_email_address) into facEmail
            from goremal where goremal_pidm = p_pidm
            and goremal_emal_code = 'IA'
            and goremal_status_ind = 'A';
            */
            Select max(gobtpac_external_user) ||  '@saskpolytech.ca' into facEmail
            from GOBTPAC where Gobtpac_pidm = p_pidm;
        
--        end if;
        
--        select count(*) into phoneCnt
--        from sprtele where sprtele_pidm = p_pidm
--        and sprtele_tele_code = 'IA'
--        and sprtele_status_ind is null
--        and sprtele_seqno = 
--            (
--                select max(sprtele_seqno)
--                from sprtele where sprtele_pidm = p_pidm
--                and sprtele_tele_code = 'IA'
--                and sprtele_status_ind is null
--            );
            
--        if phoneCnt > 0 then
            select max(sprtele_phone_area || sprtele_phone_number) into phone
            from sprtele where sprtele_pidm = p_pidm
            and sprtele_tele_code = 'IA'
            and sprtele_status_ind is null
            and sprtele_seqno = 
                (
                    select max(sprtele_seqno)
                    from sprtele where sprtele_pidm = p_pidm
                    and sprtele_tele_code = 'IA'
                    and sprtele_status_ind is null
                );
        
--        end if;

    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getFacultyContact_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getFacultyContact_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        
    END getFacultyContact_p;
    
    
    --Procedure that retrieves an instructors details.
    procedure getFacultyDetails_p (p_pidm number) is
    
    BEGIN
        facultyID := null;
        firstName := null;
        lastName := null;
        fullName := null;
        middleName := null;
        getFacultyDetails_rec := null;
        
        open getFacultyDetails_c(p_pidm);
        fetch getFacultyDetails_c into getFacultyDetails_rec;
        
        facultyID := getFacultyDetails_rec.spriden_id;
        firstName := getFacultyDetails_rec.spriden_first_name;
        lastName := getFacultyDetails_rec.spriden_last_name;
        fullName := firstName || ' ' || lastName;
        middleName := getFacultyDetails_rec.spriden_mi;

        close getFacultyDetails_c;
    

    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getFacultyDetails_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getFacultyDetails_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
    
    END getfacultyDetails_p;
    
    
    --Procedure that determines an instructors type and work status.
    procedure getInstrType_p (p_pidm number) is
    
    BEGIN
        facType := null;
        fPTime := null;
        facInd := null;
        advInd := null;
        startDate := null;
        getInst_rec := null;
        
        select decode(max(pebempl_internal_ft_pt_ind), 'F', 'Full Time', 
                                                       'P', 'Part Time', 
                                                       'O', 'Other') into fPTime
        from pebempl where pebempl_pidm = p_pidm;
        
        open getInst_c(p_pidm);
        fetch getInst_c into getInst_rec;
        
        facInd := getInst_rec.sibinst_schd_ind;
        advInd := getInst_rec.sibinst_advr_ind;
        startDate := to_date(to_char(getInst_rec.sibinst_fcst_date, 'MM/DD/YYYY'), 'MM/DD/YYYY');
        
        close getInst_c;
        
        if facInd is not null and advInd is not null then
            facType := 'Faculty/Advisor';
        
        elsif advInd is not null then
            facType := 'Advisor';
            
        elsif facInd is not null then
            facType := 'Faculty';
            
        end if;
        
        facType := facType || ' - ' || fPTime;
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getInstrType_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: ' || SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getInstrType_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: ' || SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        
    END getInstrType_p;
    
    
    --Procedure that determines a programs location.
    procedure getProgramLocn_p (p_pidm number) is
    
    BEGIN
        progDesc := null;
        schoolCode := null;
        schoolDesc := null;
        campus := null;
--        building := null;
        getProgramLocn_rec := null;
        
        open getProgramLocn_c(p_pidm);
        fetch getProgramLocn_c into getProgramLocn_rec;
        
        progDesc := getProgramLocn_rec.spraddr_street_line1;
        campus := getProgramLocn_rec.spraddr_street_line2;
--        currStreetLine3 := getProgramLocn_rec.spraddr_street_line3;
        
        close getProgramLocn_c;
        
        select max(szbsprg_school) into schoolCode
        from szbsprg where szbsprg_prog_name = progDesc;
        
        if schoolCode is not null then
            select szr_schools_title into schoolDesc
            from szr_schools where szr_schools_id = schoolCode;
            
        end if;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getProgramLocn_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getProgramLocn_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
            
    END getProgramLocn_p;
    
    
    --Procedure that determines if a new faculty record is the same as the old faculty record.
    procedure getSameRec_p(p_facPidm number, p_facultyID varchar2, p_userName varchar2, p_fName varchar2, p_lName varchar2, p_fullName varchar2, 
        p_mName varchar2, p_facEmail varchar2, p_phone varchar2, p_facType varchar2, p_progDesc varchar2, p_school varchar2, p_campus varchar2, 
        p_startDate date) is
    
    BEGIN
        toInsertUpdate := 'Y'; 
        getSameRec_rec := null;

        open getSameRec_c(p_facPidm, p_facultyID, p_userName, p_fName, p_lName, p_fullName, p_mName, p_facEmail, p_phone, 
                         p_facType, p_progDesc, p_school, p_campus, p_startDate);
        fetch getSameRec_c into getSameRec_rec;
        
        if getSameRec_rec.inSZBSYMFSame = 'S' then
            toInsertUpdate := 'N';
        
        end if;
        
        close getSameRec_c;
        
     
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getSameRec_p Exception - No Data Found';
            msg := 'PIDM: ' || p_facPidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getSameRec_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_facPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
    
    END getSameRec_p;
    
    
    --Procedure that determines if a new record is for insert or update.
    procedure getUpdate_p(p_facPidm number) is
    
    BEGIN
        toUpdate := 'N';
        getUpdate_rec := null;
        
        open getUpdate_c(p_facPidm);
        fetch getUpdate_c into getUpdate_rec;
        
        if getUpdate_rec.inSZBSYMFUpdate = 'U' then
            toUpdate := 'Y';
            
        end if;
        
        close getUpdate_c;
        
    
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getUpdate_p Exception - No Data Found';
            msg := 'PIDM: ' || p_facPidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getUpdate_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_facPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;

    END getUpdate_p;    
    
    
    --Procedure to retrieve an instructors username.
    procedure getUserName_p (p_pidm number) is
    
    BEGIN
        userName := null;
        
        select gobtpac_external_user into userName
        from GOBTPAC where gobtpac_pidm = p_pidm;
        
        userName := userName || '@saskpolytech.ca';
        
        
    EXCEPTION
        WHEN no_data_found THEN        
            subjct := 'symplicityFacultyDataLoad.getUserName_p Exception - No Data Found';
            msg := 'PIDM: ' || p_pidm || utl_tcp.crlf || 'SQLCODE: ' || TO_CHAR( SQLCODE) || utl_tcp.crlf ||'.SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
        WHEN too_many_rows THEN
            subjct := 'symplicityFacultyDataLoad.getUserName_p Exception - Too Many Rows';
            msg := 'PIDM: ' || p_pidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;
    
    END getUserName_p;

    
    --Procedure to insert a new record into SZBSYMF.
    procedure insert_szbsymf_p(p_facPidm number, p_facultyID varchar2, p_userName varchar2, p_fName varchar2, p_lName varchar2, p_fullName varchar2, 
        p_mName varchar2, p_facEmail varchar2, p_phone varchar2, p_facType varchar2, p_progDesc varchar2, p_school varchar2, p_campus varchar2, p_startDate date) is

    BEGIN
        INSERT INTO saturn.SZBSYMF
        (
            SZBSYMF_PIDM,
            SZBSYMF_FACULTYID,
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
            SZBSYMF_STARTDATE,
            SZBSYMF_ADDDATE,
            SZBSYMF_ACTIVITYDATE
        )
        VALUES
        (
            p_facPidm,
            p_facultyID,
            p_userName,
            p_fName,
            p_lName,
            p_fullName,
            p_mName,
            p_facEmail,
            p_phone, 
            p_facType,
            p_progDesc,
            p_school,
            p_campus,
            p_startDate,
            sysdate,
            sysdate
        );
        
    END insert_szbsymf_p;
    
    
    --Procedure to insert an old record into the history/repeating table SZRSYMF.
    procedure insert_szrsymf_p(p_facPidm number) is
    
    BEGIN
        getExistingRec_rec := null;
        
        open getExistingRec_c(p_facPidm);
        fetch getExistingRec_c into getExistingRec_rec;
        
        INSERT INTO saturn.SZRSYMF
        (
            SZRSYMF_PIDM,
            SZRSYMF_FACULTYID,
            SZRSYMF_USERNAME,
            SZRSYMF_FIRSTNAME,
            SZRSYMF_LASTNAME,
            SZRSYMF_FULLNAME,
            SZRSYMF_MIDDLENAME,
            SZRSYMF_EMAIL,
            SZRSYMF_PHONE,
            SZRSYMF_FACTYPE,
            SZRSYMF_PROGDESC,
            SZRSYMF_SCHOOL,
            SZRSYMF_CAMPUS,
            SZRSYMF_STARTDATE,
            SZRSYMF_SZRADDDATE,
            SZRSYMF_SZRACTIVITYDATE
        )
        VALUES
        (
            getExistingRec_rec.SZBSYMF_PIDM,
            getExistingRec_rec.SZBSYMF_FACULTYID,
            getExistingRec_rec.SZBSYMF_USERNAME,
            getExistingRec_rec.SZBSYMF_FIRSTNAME,
            getExistingRec_rec.SZBSYMF_LASTNAME,
            getExistingRec_rec.SZBSYMF_FULLNAME,
            getExistingRec_rec.SZBSYMF_MIDDLENAME,
            getExistingRec_rec.SZBSYMF_EMAIL,
            getExistingRec_rec.SZBSYMF_PHONE,
            getExistingRec_rec.SZBSYMF_FACTYPE,
            getExistingRec_rec.SZBSYMF_PROGDESC,
            getExistingRec_rec.SZBSYMF_SCHOOL,
            getExistingRec_rec.SZBSYMF_CAMPUS,
            getExistingRec_rec.SZBSYMF_STARTDATE,
            sysdate,
            sysdate
        );
        
        close getExistingRec_c;
        
    END insert_szrsymf_p;
        


BEGIN
    --Retrieve all instructors with assignments and their details.
    open getAsgnPidm_c;
    loop
        fetch getAsgnPidm_c into getAsgnPidm_rec;
        exit when getAsgnPidm_c%notfound;
        
        facPidm := getAsgnPidm_rec.sirasgn_pidm;
        
        getUserName_p(facPidm);
        
        getFacultyDetails_p(facPidm);
        
        getFacultyContact_p(facPidm);
        
        getInstrType_p(facPidm);
        
        getProgramLocn_p(facPidm);
        
--        DBMS_OUTPUT.PUT_LINE(facPidm || ', ' || facultyID || ', ' || userName || ', ' ||  firstName || ', ' || lastName || ', ' ||
--                    fullName || ', ' || facEmail || ', ' || phone || ', ' || facType || ', ' || progDesc || ', ' || schoolDesc || ', ' || campus || ', ' || startDate || ', EOR');
        
        --Compare the new record to the exising record to see if there are any changes.
        getSameRec_p(facPidm, facultyID, userName, firstName, lastName, fullName, middleName, facEmail, phone, facType, progDesc, schoolDesc, campus, startDate);

        --If the record is new or there are changes, insert or update.
        if toInsertUpdate = 'Y' then
            --Determine if the record is to be updated.
            getUpdate_p(facPidm);
            
            --If the record is to be updated.
            if toUpdate = 'Y' then           
                --Insert the old record into the history/repeating table SZRSYMF.
                insert_szrsymf_p(facPidm);
                
                --Update existing record with new changes.
                UPDATE SZBSYMF
                SET SZBSYMF_FACULTYID = facultyID,
                    SZBSYMF_USERNAME = userName,
                    SZBSYMF_FIRSTNAME = firstName,
                    SZBSYMF_LASTNAME = lastName,
                    SZBSYMF_FULLNAME = fullName,
                    SZBSYMF_MIDDLENAME = middleName,
                    SZBSYMF_EMAIL = facEmail,
                    SZBSYMF_PHONE = phone,
                    SZBSYMF_FACTYPE = facType,
                    SZBSYMF_PROGDESC = progDesc,
                    SZBSYMF_SCHOOL = schoolDesc,
                    SZBSYMF_CAMPUS = campus,
                    SZBSYMF_STARTDATE = startDate,
                    SZBSYMF_ACTIVITYDATE = sysdate      
                WHERE SZBSYMF_PIDM = facPidm;
            
            --Insert a new record to SZBSYMF.
            else
                insert_szbsymf_p(facPidm, facultyID, userName, firstName, lastName, fullName, middleName, facEmail, phone, facType, progDesc, schoolDesc, campus, startDate);
                
            end if;
            
        end if;            

    end loop;
    close getAsgnPidm_c;
    
    COMMIT;
    

EXCEPTION
    WHEN OTHERS THEN
        rollback;
        subjct := 'symplicityFacultyDataLoad Exception';
        msg := 'PIDM: ' || facPidm || ' - SQLCODE: ' || TO_CHAR( SQLCODE) || ' - .SQLERRM: '||SQLERRM;
            insert into saturn.SYMPERRORMSGS(SYMPERRORMSGS_subject, SYMPERRORMSGS_message, SYMPERRORMSGS_activity_date) 
                values (subjct, msg, sysdate); 
--            commit;


END symplicityFacultyDataLoad;
/
