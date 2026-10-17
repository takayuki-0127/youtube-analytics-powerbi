-- youtube_analysis.sql（最新版・2026-10-16）
-- ※ SSMS のスクリーンショットから書き起こしたもの。
-- ✅ 2026-10-17 確認済み（sql/09_verify_youtube_analysis.sql で実行）：v_video は今のビューと差分0行、1〜4の答え合わせもすべて一致 → screenshots/sql_09_verify.png
-- ※ 最終行の「;GO」が1行にくっついていたのを修正した
USE youtube_dashboard;
GO

/* ============================================================
   1. 動画一覧の整形ビュー dbo.v_video
   答え合わせ：Shorts 201・長尺 138・Live 3
   ============================================================ */
CREATE OR ALTER VIEW dbo.v_video AS
SELECT
    TRIM(VideoId)                                   AS VideoId,
    VideoTitle,
    TRY_PARSE(PublishedAt AS date USING 'en-US')    AS PublishedDate,
    TRY_CONVERT(int, DurationSec)                   AS DurationSec,
    ISNULL(TRY_CONVERT(int, Views), 0)              AS Views,
    ISNULL(TRY_CONVERT(decimal(12, 4), WatchHours), 0) AS WatchHours,
    ISNULL(TRY_CONVERT(int, SubscribersNet), 0)     AS SubscribersNet,
    ISNULL(TRY_CONVERT(int, Impressions), 0)        AS Impressions,
    CASE
        WHEN TRY_CONVERT(int, DurationSec) = 0
          OR VideoTitle LIKE N'%LIVE%'              THEN N'Live'
        WHEN TRY_CONVERT(int, DurationSec) <= 60    THEN N'Shorts'
        ELSE N'長尺'
    END                                             AS ContentType
FROM stg.videos
WHERE VideoId <> N'合計';
GO

SELECT ContentType, COUNT(*) AS Videos, SUM(Views) AS Views
FROM dbo.v_video
GROUP BY ContentType
ORDER BY Videos DESC;
GO

/* ============================================================
   2. 7日移動平均（カレンダーで視聴0回の日を0で埋める）＋前週同曜日
   答え合わせ：10/14 = 602.29、10/13 = 631.71（Power BI の DAX と一致）
   ============================================================ */
WITH calendar AS (
    SELECT DATEADD(day, value, CAST('2026-07-14' AS date)) AS [Date]
    FROM GENERATE_SERIES(0, DATEDIFF(day, '2026-07-14', '2026-10-14'))
),
daily AS (
    SELECT c.[Date], ISNULL(d.Views, 0) AS Views
    FROM calendar AS c
    LEFT JOIN dbo.v_daily AS d ON d.[Date] = c.[Date]
),
ma AS (
    SELECT [Date], Views,
           AVG(CAST(Views AS decimal(10, 2))) OVER (
               ORDER BY [Date] ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS MovingAvg7,
           LAG(Views, 7) OVER (ORDER BY [Date]) AS ViewsSameDayLastWeek
    FROM daily
)
SELECT *
FROM ma
WHERE [Date] >= '2026-10-05'
ORDER BY [Date];
GO

/* ============================================================
   3. 公開週（ISO週・月曜始まり）ごとの Shorts と長尺の比較
   答え合わせ：27行、本数の累計が Shorts 195・長尺 138
   ============================================================ */
WITH weekly AS (
    SELECT
        DATETRUNC(iso_week, PublishedDate) AS WeekStart,   -- 月曜始まり
        ContentType,
        COUNT(*)        AS Videos,
        SUM(Views)      AS Views,
        SUM(WatchHours) AS WatchHours
    FROM dbo.v_video
    WHERE PublishedDate IS NOT NULL
      AND ContentType IN (N'Shorts', N'長尺')
    GROUP BY DATETRUNC(iso_week, PublishedDate), ContentType
)
SELECT
    WeekStart,
    ContentType,
    Videos,
    Views,
    CAST(Views * 1.0 / Videos AS decimal(10, 1))                          AS ViewsPerVideo,
    CAST(Views * 100.0 / SUM(Views) OVER (PARTITION BY WeekStart)
         AS decimal(5, 1))                                                AS ViewsSharePct,
    CAST(WatchHours * 100.0 / SUM(WatchHours) OVER (PARTITION BY WeekStart)
         AS decimal(5, 1))                                                AS WatchHoursSharePct,
    Views - LAG(Views) OVER (PARTITION BY ContentType ORDER BY WeekStart) AS ViewsVsPrevWeek,
    SUM(Videos) OVER (PARTITION BY ContentType ORDER BY WeekStart
                      ROWS UNBOUNDED PRECEDING)                           AS VideosCumulative
FROM weekly
ORDER BY WeekStart, ContentType;
GO

/* ============================================================
   4. 公開から7日間の伸び（種類ごとの上位5本）
   答え合わせ：Shorts 1位 "They Are In for the Night" 945回（初日354・37.5%）
   ============================================================ */
WITH vd AS (
    SELECT TRIM(d.VideoId) AS VideoId,
           TRY_CONVERT(date, d.[Date]) AS [Date],
           ISNULL(TRY_CONVERT(int, d.Views), 0) AS Views
    FROM stg.video_daily AS d
),
first7 AS (
    SELECT v.VideoId, v.VideoTitle, v.ContentType, v.PublishedDate,
           DATEDIFF(day, v.PublishedDate, vd.[Date]) AS DayN,
           vd.Views,
           SUM(vd.Views) OVER (PARTITION BY v.VideoId ORDER BY vd.[Date]
                               ROWS UNBOUNDED PRECEDING) AS CumViews
    FROM vd
    JOIN dbo.v_video AS v ON v.VideoId = vd.VideoId
    WHERE v.PublishedDate <= '2026-10-08'
      AND vd.[Date] BETWEEN v.PublishedDate AND DATEADD(day, 6, v.PublishedDate)
),
summary AS (
    SELECT VideoTitle, ContentType, PublishedDate,
           ISNULL(SUM(CASE WHEN DayN = 0 THEN Views END), 0) AS Day1Views,
           MAX(CumViews) AS Day7Views,
           CAST(ISNULL(SUM(CASE WHEN DayN = 0 THEN Views END), 0) * 100.0
                / NULLIF(MAX(CumViews), 0) AS decimal(5, 1)) AS Day1SharePct,
           RANK() OVER (PARTITION BY ContentType ORDER BY MAX(CumViews) DESC) AS RankInType
    FROM first7
    GROUP BY VideoId, VideoTitle, ContentType, PublishedDate
)
SELECT ContentType, RankInType, VideoTitle, PublishedDate,
       Day1Views, Day7Views, Day1SharePct
FROM summary
WHERE RankInType <= 5
ORDER BY ContentType, RankInType;
GO

