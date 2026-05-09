# FinOps360-Financial-Operations-Analysis
End-to-end Financial Operations Analysis project covering Revenue Forecasting, Churn Analysis, &amp; Profitability using MS Excel, MYSQL and Power BI | NexaCloud Solutions (SaaS B2B)
### NexaCloud Solutions | FY2022–FY2024



![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=for-the-badge&logo=powerbi&logoColor=black)




![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)




![Excel](https://img.shields.io/badge/Microsoft%20Excel-217346?style=for-the-badge&logo=microsoftexcel&logoColor=white)



---

## 📌 Project Overview

NexaCloud Solutions, a fictional B2B SaaS company, is experiencing above-industry 
churn rates and requires data-driven visibility into its revenue health, customer 
retention, and product-line profitability to support FY2026 strategic planning.

This project delivers an end-to-end Financial Operations Intelligence Platform 
covering revenue forecasting, churn analysis, and profitability — built entirely 
using MS Excel, MySQL, and Power BI.

---

## 🎯 Business Problem

> *"NexaCloud's leadership needs visibility into revenue health, customer churn 
> risk, and product-line profitability to make data-driven decisions for 
> FY2026 planning."*

---

## 🛠 Tool Stack

| Tool | Purpose |
|---|---|
| **MS Excel** | Dataset creation, data dictionary |
| **MySQL 8.0** | Star schema design, data warehousing, SQL analytics |
| **Power BI** | Interactive dashboard, DAX measures, forecasting |

---

## 📁 Project Structure
FinOps360-Financial-Operations-Analysis/
├── sql/
│   ├── 01_schema_and_tables.sql
│   ├── 02_date_dimension.sql
│   ├── 03_load_data.sql
│   ├── 04_data_cleaning.sql
│   ├── 05_revenue_analysis.sql
│   ├── 06_churn_analysis.sql
│   └── 07_profitability_analysis.sql
├── data/
│   └── FinOps360_NexaCloud_Dataset.xlsx
├── screenshots/
│   ├── 01_executive_summary.png
│   ├── 02_revenue_analysis.png
│   ├── 03_churn_retention.png
│   ├── 04_profitability.png
│   └── 05_insights_recommendations.png
├── FinOps360.pdf
└── README.md


---

## 🗄 Database Design

Star schema with 3 dimension tables and 3 fact tables:

| Table | Type | Rows |
|---|---|---|
| `dim_customers` | Dimension | 1,200 |
| `dim_date` | Dimension | 1,096 |
| `dim_product` | Dimension | 25 |
| `fact_transactions` | Fact | 5,000 |
| `fact_churn` | Fact | 210 |
| `fact_budget_vs_actual` | Fact | 216 |

---

## 📊 Dashboard Pages

### Page 1 — Executive Summary
High-level KPI overview with total revenue, MRR, ARR, churn rate, 
gross margin, and active customers. Includes revenue trend, 
segment distribution, and churn by reason.

### Page 2 — Revenue Analysis
Monthly revenue trend with 6-month forecast, revenue by product line, 
category heatmap, and recurring vs non-recurring revenue split.

### Page 3 — Churn & Retention
Churn by reason, plan, and segment. Monthly churn trend, health status 
distribution, win-back opportunities, and voluntary vs involuntary churn split.

### Page 4 — Profitability
Budget vs actual by department, gross margin by product line treemap, 
EBITDA trend, and revenue variance analysis.

### Page 5 — Insights & Recommendations
Executive summary of key findings and 5 strategic recommendations 
for NexaCloud leadership.

---

## 📸 Dashboard Screenshots

### Executive Summary


![Executive Summary](screenshots/01_executive_summary.png)<img width="569" height="325" alt="Executive Summary" src="https://github.com/user-attachments/assets/66941911-32c3-457f-8540-758b02615c54" />




### Revenue Analysis


![Revenue Analysis](screenshots/02_revenue_analysis.png)<img width="566" height="322" alt="Revenue Analysis" src="https://github.com/user-attachments/assets/2743196d-d819-4c05-8f1a-23dc1898c972" />




### Churn & Retention


![Churn & Retention](screenshots/03_churn_retention.png)<img width="565" height="320" alt="Churn and Retention" src="https://github.com/user-attachments/assets/2d3dec9b-8455-4d0a-a385-9c6128ea28d5" />




### Profitability


![Profitability](screenshots/04_profitability.png)<img width="566" height="323" alt="Profitablilty Analysis" src="https://github.com/user-attachments/assets/c06191be-5b02-442a-8683-540b7bb376af" />




### Insights & Recommendations


![Insights](screenshots/05_insights_recommendations.png)<img width="565" height="320" alt="Insights and Recommendations" src="https://github.com/user-attachments/assets/3f3f417f-7f44-49db-abe0-045a5e959db8" />




---

## 🔑 Key Metrics

| Metric | Value |
|---|---|
| Total Revenue | ₹41.63M |
| Gross Margin | 67.96% |
| Churn Rate | 17.5% |
| Churned Customers | 210 |
| Avg Days to Churn | 485 Days |
| YoY Revenue Growth | 202.38% |
| Avg Monthly Revenue | ₹1.16M |

---

## 💡 Key Insights

- **Revenue:** Subscription revenue drives 60%+ of total revenue. 
  Analytics Add-on leads gross margin at 68.47%
- **Churn:** 17.5% churn rate is above the 5–7% industry benchmark. 
  Price and Competition are the top 2 churn drivers
- **Profitability:** Gross margin of 67.96% exceeds SaaS industry average. 
  Professional Services carries highest COGS pressure at 55%
- **Budget:** G&A and R&D departments consistently exceed budget — 
  flagged for cost control intervention

---

## ✅ Strategic Recommendations

1. **Reduce Churn** — Launch proactive CSM outreach for Critical and 
   At Risk customers. Target: reduce churn below 10%
2. **Pricing Strategy** — Review Starter plan pricing. Consider lower 
   entry-tier or flexible billing options
3. **Expand High-Margin Products** — Prioritize Analytics Add-on and 
   API Suite upsell campaigns
4. **Cost Control** — Implement quarterly budget review for G&A and R&D
5. **Win-Back Campaign** — Engage win-back eligible churned customers. 
   20% recovery could add significant MRR

---

## 👤 Author

**Dhananjay Singh**
Aspiring Data / Business Analyst
📧 [thedhananjaysingh07@gmail.com]
🔗 [https://www.linkedin.com/in/dhananjay-singh-gautam-445534375?utm_source=share_via&utm_content=profile&utm_medium=member_android]

---

*This is a portfolio project using synthetic data generated for analytical purposes. 
NexaCloud Solutions is a fictional company.*






















