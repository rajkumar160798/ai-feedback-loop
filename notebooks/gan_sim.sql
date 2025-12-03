-- =====================================================================
-- PHASE 2: Rebuild cav_link_visit_detail with FIXED NGX JOIN
-- =====================================================================

CREATE OR REPLACE TABLE anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail
OPTIONS (
    description = 'call after visit by link visit detail (fixed deduplication)',
    labels = [("owner", "wusinichm2_aetna_com")]
) AS

WITH ngx_session AS (
    SELECT DISTINCT
        post_visid_high,
        post_visid_low,
        visit_num,
        visit_start_time_gmt,
        post_evar41
    FROM edp-prod-hcbstorage.edp_hcb_core_srcv.ADOBE_NGX
    WHERE EVENT_DATE_TIME_PARTITION BETWEEN TIMESTAMP('2025-10-01')
      AND TIMESTAMP('2025-10-31 23:59:59')
)

SELECT
    v.individual_analytics_identifier,
    v.session_id,
    v.login_ind,
    v.web_mobile,
    v.user_platform,
    v.visit_start_date_time,
    PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', v.visit_start_date_time, 'America/New_York')
        AS visit_start_date_time_utc,
    v.visit_date,
    m.lob_cd,
    m.lob_ind_v_group,
    m.indiv_anlytcs_id,
    m.indiv_anlytcs_sbscrbr_id,
    m.cust_nm,
    m.member_status,
    m.year_month,
    COUNT(1) AS cnt_hits,
    tag.r,
    tag.post_evar41,

    -- FIXED: REAL call identifier (not count)
    c.unique_id AS call_id

FROM anbc-hcb-prod.ah_reports_hcb_prod.visit_hx AS v

JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_member_base AS m
    ON v.individual_analytics_identifier = m.indiv_anlytcs_sbscrbr_id

-- FIXED: Join deduped NGX SESSION instead of full NGX table
JOIN ngx_session AS an
    ON v.session_id = CONCAT(
        an.post_visid_high, '~',
        an.post_visid_low, '~',
        an.visit_num, '~',
        an.visit_start_time_gmt
    )

JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_value_inventory AS tag
    ON tag.post_evar41 = an.post_evar41

LEFT JOIN anbc-hcb-prod.ah_reports_hcb_prod.call_hx AS c
    ON c.indiv_anlytcs_sbscrbr_id = v.individual_analytics_identifier
   AND c.event_time BETWEEN PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', v.visit_start_date_time, 'America/New_York')
                         AND TIMESTAMP_ADD(
                              PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', v.visit_start_date_time, 'America/New_York'),
                              INTERVAL 48 HOUR
                         )

GROUP BY
    v.individual_analytics_identifier,
    v.session_id,
    v.login_ind,
    v.web_mobile,
    v.user_platform,
    v.visit_start_date_time,
    v.visit_date,
    m.lob_cd,
    m.lob_ind_v_group,
    m.indiv_anlytcs_id,
    m.indiv_anlytcs_sbscrbr_id,
    m.cust_nm,
    m.member_status,
    m.year_month,
       tag.r,
    tag.post_evar41,
    c.unique_id;

-- =====================================================================
-- PHASE 3: Build Corrected Summary Table
-- =====================================================================

CREATE OR REPLACE TABLE anbc-hcb-dev.ah_reports_hcb_dev.cav_link_call_summary
OPTIONS (
    description = 'call after visit summary (corrected session-level call rate)',
    labels = [("owner", "wusinichm2_aetna_com")]
) AS

SELECT
    vd.year_month,
    vd.post_evar41,
    vd.lob_cd,
    inv.r AS link_rank,

    COUNT(DISTINCT vd.session_id) AS total_sessions,
    SUM(vd.cnt_hits) AS total_hits,

    COUNT(DISTINCT vd.call_id) AS total_calls,

    -- CORRECT CALL RATE: sessions with call / total sessions
    CASE WHEN COUNT(DISTINCT vd.session_id) > 0 THEN
        COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END) * 1.0
        / COUNT(DISTINCT vd.session_id)
    ELSE 0 END AS call_after_rate,

    -- Additional diagnostics
    COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END)
        AS unique_sessions_with_calls,

    SUM(CASE WHEN vd.call_id IS NOT NULL THEN 1 ELSE 0 END)
        AS raw_rows_with_calls,

    CASE WHEN COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END) > 0
         THEN COUNT(DISTINCT vd.call_id) * 1.0
              / COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END)
         ELSE 0 END AS avg_calls_per_session_with_calls

FROM anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail AS vd

JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_value_inventory AS inv
    ON vd.post_evar41 = inv.post_evar41

GROUP BY
    vd.year_month,
    vd.post_evar41,
    vd.lob_cd,
    inv.r

ORDER BY link_rank;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN call_id IS NOT NULL THEN session_id END) AS sessions_with_calls,
    COUNT(CASE WHEN call_id IS NOT NULL THEN 1 END) AS rows_with_calls,
    COUNT(DISTINCT call_id) AS distinct_calls
FROM anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail;
