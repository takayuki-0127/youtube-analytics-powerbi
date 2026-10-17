-- クエリ③'：公開から7日間の伸び（上位24本：長尺12・Shorts12 のうち、10/8までに公開した22本）
-- 答え合わせ：22行。Shorts 1位 "They Are In for the Night" 945回（初日354＝37.5%）
USE youtube_dashboard;
WITH first7 AS (
    SELECT
        VideoId, VideoTitle, ContentType, PublishedDate, DaysSincePublish, Views,
        SUM(Views) OVER (PARTITION BY VideoId ORDER BY [Date]
                         ROWS UNBOUNDED PRECEDING)          AS 累計,
        SUM(Views) OVER (PARTITION BY VideoId)              AS 七日合計
    FROM dbo.v_video_daily
    WHERE DaysSincePublish BETWEEN 0 AND 6
      AND PublishedDate <= DATEADD(DAY, -6, '2026-10-14')
)
SELECT
    ContentType, VideoTitle, PublishedDate,
    MAX(七日合計)                                             AS 七日合計,
    MAX(CASE WHEN DaysSincePublish = 0 THEN Views END)        AS 初日,
    CAST(MAX(CASE WHEN DaysSincePublish = 0 THEN Views END) * 100.0
         / NULLIF(MAX(七日合計), 0) AS decimal(5,1))          AS 初日の割合pct
FROM first7
GROUP BY VideoId, ContentType, VideoTitle, PublishedDate
ORDER BY ContentType, 七日合計 DESC;
