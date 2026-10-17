USE youtube_dashboard;
GO

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