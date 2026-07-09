import re
import pandas as pd
import plotly.express as px

rows=[]

with open("metrics.txt") as f:
    for line in f:
        line=line.strip()

        if not line or line.startswith("#"):
            continue

        m=re.match(r'^(.*?)\s+([0-9eE+.-]+)\s+(\d+)$', line)
        if m:
            rows.append([m.group(1), float(m.group(2))])

df=pd.DataFrame(rows, columns=["metric","value"])

storage=df[df["metric"].str.contains("size_bytes", case=False)]

top=storage.sort_values("value", ascending=False).head(20)

fig=px.bar(
    top,
    x="value",
    y="metric",
    orientation="h",
    title="JFrog Storage Metrics"
)

fig.show()
