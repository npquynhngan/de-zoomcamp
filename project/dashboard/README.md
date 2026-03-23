# Dashboard — US Wildfire Analytics

The dashboard is built with [Looker Studio](https://lookerstudio.google.com) (formerly Google Data Studio), which connects natively to BigQuery at no cost.

## Live Dashboard

> **[Open Dashboard](https://lookerstudio.google.com)** *(link updated after deployment)*

## Screenshot Previews

### Tile 1 — Fire Count by Cause (Categorical)

Shows the total number of fires broken down by general cause (lightning, debris burning, arson, etc.) across all years and states.

![Fires by cause](screenshots/fires_by_cause.png)

### Tile 2 — Monthly Fire Trend (Temporal)

Shows the count of fires per month from 1992 to 2020, revealing strong seasonal patterns (summer peaks) and multi-year trends.

![Monthly trend](screenshots/monthly_trend.png)

## Recreating the Dashboard

### Prerequisites

- Access to the BigQuery dataset (`wildfire_data`) in your GCP project
- A Google account for Looker Studio

### Steps

1. Go to [lookerstudio.google.com](https://lookerstudio.google.com) and click **Create > Report**.

2. Choose **BigQuery** as the data source.

3. Select your GCP project > `wildfire_data` > `agg_state_stats`.

4. Click **Add to Report**.

#### Tile 1: Fire Count by Cause (Bar Chart)

1. Insert > Chart > Bar chart
2. **Dimension**: `cause`
3. **Metric**: `fire_count` (sum)
4. **Sort**: `fire_count` descending
5. Set chart title: "US Wildfire Count by Cause (1992-2020)"

#### Tile 2: Monthly Fire Trend (Time Series)

1. Add a second data source: `agg_monthly_stats`
2. Insert > Chart > Time series
3. **Dimension**: `year_month` (set type to Date, format YYYY-MM)
4. **Metric**: `fire_count` (sum)
5. Set chart title: "Monthly US Wildfire Count (1992-2020)"

#### Additional Tiles (Optional)

- **Total acres burned by state**: Geo chart using `agg_state_stats.total_acres_burned`
- **Fire size class distribution**: Stacked bar using `fct_wildfires` grouped by `fire_size_class` and `fire_year`

### Publishing

Click **Share > Manage access** and set to "Anyone with the link can view" to get a shareable public URL.
