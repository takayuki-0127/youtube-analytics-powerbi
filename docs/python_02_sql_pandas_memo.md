# pandas で公開7日間の上位5本を再現する（2026-10-17）

## 結果（SQL クエリ③'・Power BI 3ページ目と一致）
データ：YouTube Studio の動画×日別 CSV（24本・2,232行・12,742回）＋ 動画別 CSV（リポジトリには入れていない）
条件：公開日 10/08 以前（7日分そろっている動画）、公開後0〜6日目の合計

| 種類 | 順位 | 7日間の視聴回数 |
|---|---|---|
| Shorts | 1〜5位 | 945／928／896／877／860（合計 4,506） |
| 長尺 | 1〜5位 | 294／136／116／114／93（合計 753） |

- 公開日 10/08 以前の条件を外すと、10/09 以降に公開した Shorts（1,003回・947回）が上位に入り、SQL・Power BI とずれる
- ノートブック：`python/youtube_ma7.ipynb` の6セル目。結果の画面：`images/py_03_first7_top5.png`

## SQL と pandas の対応
| SQL | pandas |
|---|---|
| `JOIN dbo.v_video AS v ON v.VideoId = vd.VideoId` | `vd.merge(v[[...]], on="コンテンツ")` |
| `TRIM(VideoId)` | `.str.strip()` |
| `DATEDIFF(day, PublishedDate, [Date])` | `(m["日付"] - m["公開日"]).dt.days` |
| `WHERE … BETWEEN 0 AND 6` | `.between(0, 6)` |
| `GROUP BY ContentType, VideoId` + `SUM(Views)` | `.groupby(["種類", "コンテンツ"])["視聴回数"].sum()` |
| `RANK() OVER (PARTITION BY ContentType ORDER BY … DESC)` … `WHERE RankInType <= 5` | `.sort_values(..., ascending=False).groupby("種類").head(5)` |
| `ISNULL(Views, 0)` | `.fillna(0)` |

- 違い：`RANK()` は同じ値があると6本以上出ることがある。`head(5)` は必ず5本で切る（今回は同順位なし）

## CSVで手直ししたところ
- video_daily の CSV は先頭に BOM がある → 念のため `encoding="utf-8-sig"` で読んだ（pandas は付けなくても「日付」列を読めた）
- videos.csv に、動画IDの先頭に空白が付いたものが4本ある（- で始まるID）→ `.str.strip()` してからつなぐ（SQL の TRIM と同じ）
- Colab のセルで `(` … `)` を複数行に分けて書くと、自動インデントで崩れる → 1行ずつ代入する形にした
