-- クエリ②：公開週ごとの Shorts と長尺の比較
-- 答え合わせ：14週、Shorts 195本＋長尺 138本＝333本（公開日なし6本・Live 3本を除く）
-- 注意：視聴回数は 10/14 までの累計。最近公開した週ほど、視聴が積み上がる日数が短い
USE youtube_dashboard;
SELECT
    DATETRUNC(WEEK, PublishedDate)                                  AS 公開週,
    SUM(CASE WHEN ContentType = N'Shorts' THEN 1 ELSE 0 END)        AS Shorts本数,
    SUM(CASE WHEN ContentType = N'Shorts' THEN Views END)           AS Shorts視聴,
    SUM(CASE WHEN ContentType = N'長尺'   THEN 1 ELSE 0 END)        AS 長尺本数,
    SUM(CASE WHEN ContentType = N'長尺'   THEN Views END)           AS 長尺視聴,
    CAST(SUM(CASE WHEN ContentType = N'Shorts' THEN Views END) * 1.0
         / NULLIF(SUM(CASE WHEN ContentType = N'Shorts' THEN 1 END), 0) AS decimal(8,1)) AS Shorts1本あたり,
    CAST(SUM(CASE WHEN ContentType = N'長尺' THEN Views END) * 1.0
         / NULLIF(SUM(CASE WHEN ContentType = N'長尺' THEN 1 END), 0)   AS decimal(8,1)) AS 長尺1本あたり
FROM dbo.v_videos
WHERE PublishedDate IS NOT NULL
  AND ContentType IN (N'Shorts', N'長尺')
GROUP BY DATETRUNC(WEEK, PublishedDate)
ORDER BY 公開週;
