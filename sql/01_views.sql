-- 整形ビュー（stg → dbo）。2026-10-16 作成
-- 答え合わせ：v_daily 91行・36,577回／v_videos 342本・36,474回（Shorts 201・長尺 138・Live 3）／v_video_daily 2,232行・24本・12,742回
USE youtube_dashboard;
GO
CREATE OR ALTER VIEW dbo.v_daily AS
SELECT
    CAST([Date] AS date)                                   AS [Date],
    CAST(Views AS int)                                     AS Views,
    CAST(WatchHours AS decimal(10,4))                      AS WatchHours,
    DATEDIFF(SECOND, CAST('00:00:00' AS time),
             TRY_CAST(AvgViewDuration AS time))            AS AvgViewDurationSec
FROM stg.daily_metrics
WHERE [Date] <> N'合計';
GO
CREATE OR ALTER VIEW dbo.v_videos AS
SELECT
    TRIM(VideoId)                                            AS VideoId,
    VideoTitle,
    CASE WHEN NULLIF(PublishedAt, N'') IS NULL THEN NULL
         ELSE DATEFROMPARTS(
              CAST(RIGHT(PublishedAt, 4) AS int),
              (CHARINDEX(LEFT(PublishedAt, 3), 'JanFebMarAprMayJunJulAugSepOctNovDec') + 2) / 3,
              CAST(SUBSTRING(PublishedAt, 5, CHARINDEX(',', PublishedAt) - 5) AS int))
    END                                                      AS PublishedDate,
    TRY_CAST(NULLIF(DurationSec, N'') AS int)                AS DurationSec,
    TRY_CAST(NULLIF(Views, N'') AS int)                      AS Views,
    TRY_CAST(NULLIF(WatchHours, N'') AS decimal(10,4))       AS WatchHours,
    TRY_CAST(NULLIF(SubscribersNet, N'') AS int)             AS SubscribersNet,
    TRY_CAST(NULLIF(Impressions, N'') AS int)                AS Impressions,
    TRY_CAST(NULLIF(CtrPct, N'') AS decimal(6,2))            AS CtrPct,
    CASE
        WHEN TRY_CAST(DurationSec AS int) = 0
          OR VideoTitle LIKE N'%LIVE%'          THEN N'Live'
        WHEN TRY_CAST(DurationSec AS int) <= 60 THEN N'Shorts'
        ELSE N'長尺'
    END                                                      AS ContentType
FROM stg.videos;
GO
CREATE OR ALTER VIEW dbo.v_video_daily AS
SELECT
    CAST(d.[Date] AS date)                          AS [Date],
    TRIM(d.VideoId)                                 AS VideoId,
    v.VideoTitle,
    v.ContentType,
    v.PublishedDate,
    DATEDIFF(DAY, v.PublishedDate, CAST(d.[Date] AS date)) AS DaysSincePublish,
    TRY_CAST(NULLIF(d.Views, N'') AS int)           AS Views
FROM stg.video_daily d
LEFT JOIN dbo.v_videos v
       ON v.VideoId = TRIM(d.VideoId);
GO
