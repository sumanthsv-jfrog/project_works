import re
import pandas as pd
import plotly.express as px

rows = []

with open("metrics.txt") as f:
    for line in f:
        line = line.strip()

        if not line or line.startswith("#"):
            continue

        m = re.match(r'^(.*?)\s+([0-9eE+.-]+)\s+(\d+)$', line)

        if m:
            metric = m.group(1)
            value = float(m.group(2))
            ts = int(m.group(3))

            rows.append([metric, value, ts])

df = pd.DataFrame(rows, columns=["metric", "value", "timestamp"])

top = df.sort_values("value", ascending=False).head(20)

fig = px.bar(
    top,
    x="value",
    y="metric",
    orientation="h",
    title="Top 20 JFrog Metrics by Value"
)

fig.show()
