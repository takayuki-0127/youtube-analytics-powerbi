-- クエリ①：7日移動平均（答え合わせ：2026-10-14 = 602.29）
-- 注意：ROWS は行数で数える。視聴0回の日（7/14・7/16）は行がないため、7月初めは「7日」ではなく「7行」の平均になる
USE youtube_dashboard;
SELECT
    [Date],
    Views,
    AVG(CAST(Views AS decimal(10,2))) OVER (
        ORDER BY [Date]
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS MovingAvg7
FROM dbo.v_daily
ORDER BY [Date] DESC;
