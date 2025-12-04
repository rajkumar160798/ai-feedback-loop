CREATE OR REPLACE TABLE anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail OPTIONS (
    description = 'call after visit by link visit detail (fixed)',
    labels = [("owner", "wusinichm2_aetna_com")]
) AS
WITH ngx_session_link AS (
    -- One row per (session_id, post_evar41), plus hits per session-link
    SELECT
        CONCAT(
            post_visid_high, '~',
            post_visid_low, '~',
            visit_num, '~',
            visit_start_time_gmt
        ) AS session_id,
        post_evar41,
        COUNT(1) AS cnt_hits
    FROM edp-prod-hcbstorage.edp_hcb_core_srcv.ADOBE_NGX
    WHERE EVENT_DATE_TIME_PARTITION BETWEEN TIMESTAMP('2025-10-01')
        AND TIMESTAMP('2025-10-31 23:59:59')
    GROUP BY
        session_id,
        post_evar41
)
SELECT
    v.individual_analytics_identifier,
    v.session_id,
    v.login_ind,
    v.web_mobile,
    v.user_platform,
    v.visit_start_date_time,
    PARSE_TIMESTAMP(
        '%Y-%m-%d %H:%M:%S',
        v.visit_start_date_time,
        'America/New_York'
    ) AS visit_start_date_time_utc,
    v.visit_date,

    -- member info
    m.lob_cd,
    m.lob_ind_v_group,
    m.indiv_anlytcs_id,
    m.indiv_anlytcs_sbscrbr_id,
    m.cust_nm,
    m.member_status,
    m.year_month,

    -- link & inventory
    tag.r,
    tag.post_evar41,
    ngx.cnt_hits,

    -- REAL call identifier (no counting here)
    c.unique_id AS call_id

FROM anbc-hcb-prod.ah_reports_hcb_prod.visit_hx AS v

JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_member_base AS m
    ON v.individual_analytics_identifier = m.indiv_anlytcs_id   -- member → visit

JOIN ngx_session_link AS ngx
    ON v.session_id = ngx.session_id                            -- visit → NGX (session+link)

JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_value_inventory AS tag
    ON tag.post_evar41 = ngx.post_evar41                        -- link inventory

LEFT JOIN anbc-hcb-prod.ah_reports_hcb_prod.call_hx AS c
    ON c.indiv_anlytcs_sbscrbr_id = m.indiv_anlytcs_sbscrbr_id  -- call → subscriber
   AND c.event_time BETWEEN PARSE_TIMESTAMP(
                            '%Y-%m-%d %H:%M:%S',
                            v.visit_start_date_time,
                            'America/New_York'
                        )
                        AND TIMESTAMP_ADD(
                            PARSE_TIMESTAMP(
                                '%Y-%m-%d %H:%M:%S',
                                v.visit_start_date_time,
                                'America/New_York'
                            ),
                            INTERVAL 48 HOUR
                        );


CREATE OR REPLACE TABLE anbc-hcb-dev.ah_reports_hcb_dev.cav_link_call_summary OPTIONS (
    description = 'call after visit by link summary with corrected call rates',
    labels = [("owner", "wusinichm2_aetna_com")]
) AS
SELECT
    vd.year_month,
    vd.post_evar41,
    vd.lob_cd,
    inv.r AS link_rank,

    COUNT(DISTINCT vd.session_id) AS total_sessions,
    SUM(vd.cnt_hits) AS total_hits,

    -- count real unique calls
    COUNT(DISTINCT vd.call_id) AS total_calls,

    -- Correct call-after rate: sessions_with_calls / total_sessions
    CASE
        WHEN COUNT(DISTINCT vd.session_id) > 0 THEN
            COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END) * 1.0
            / COUNT(DISTINCT vd.session_id)
        ELSE 0
    END AS call_after_rate,

    -- Sessions that had at least one call
    COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END)
        AS sessions_with_calls,

    -- For debugging: how many rows in detail actually have a call
    SUM(CASE WHEN vd.call_id IS NOT NULL THEN 1 ELSE 0 END)
        AS rows_with_calls,

    -- Avg calls per calling session
    CASE
        WHEN COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END) > 0 THEN
            COUNT(DISTINCT vd.call_id) * 1.0
            / COUNT(DISTINCT CASE WHEN vd.call_id IS NOT NULL THEN vd.session_id END)
        ELSE 0
    END AS avg_calls_per_session_with_calls

FROM anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail AS vd
JOIN anbc-hcb-dev.ah_reports_hcb_dev.cav_link_value_inventory AS inv
    ON vd.post_evar41 = inv.post_evar41
GROUP BY
    vd.year_month,
    vd.post_evar41,
    vd.lob_cd,
    inv.r
ORDER BY
    link_rank;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN call_id IS NOT NULL THEN session_id END) AS sessions_with_calls,
    COUNT(CASE WHEN call_id IS NOT NULL THEN 1 END) AS rows_with_calls,
    COUNT(DISTINCT call_id) AS distinct_calls
FROM anbc-hcb-dev.ah_reports_hcb_dev.cav_link_visit_detail;

