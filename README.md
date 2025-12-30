⚽ Soccer Player Performance Analyzer

An interactive R Shiny application for visualizing and comparing soccer player performance using radar plots, powered by real FIFA player ratings from the European Soccer Database.

📊 Compare up to 4 players simultaneously across customizable FIFA attributes to uncover strengths, weaknesses, and playing styles.

📸 Preview
<img width="1722" height="910" alt="Image" src="https://github.com/user-attachments/assets/7192137f-060e-4332-a29c-d5f77500771a" />

<img width="1246" height="925" alt="Image" src="https://github.com/user-attachments/assets/63041485-d2bb-47dc-827f-4979a8e2e14a" />

<img width="1252" height="916" alt="Image" src="https://github.com/user-attachments/assets/4847018f-69c3-4e9f-b4e7-50742ab8f5f1" />

<img width="1245" height="412" alt="Image" src="https://github.com/user-attachments/assets/dc6f97af-36fe-45d3-b42e-95cefb9b47ed" />

<img width="1258" height="694" alt="Image" src="https://github.com/user-attachments/assets/8ba32392-57f8-4555-916c-3c2cd154dd22" />

<img width="381" height="845" alt="Image" src="https://github.com/user-attachments/assets/03d29457-7e2d-4f74-acea-6c5ca1e73215" />

📊 Overview

This project enables interactive exploration of soccer player performance through radar plots and data tables. Users can dynamically filter players, select metrics, and visually compare profiles across offensive, defensive, technical, and physical attributes.

Live Demo:
👉 Add your deployed Shiny app link here (e.g., shinyapps.io)

✨ Features
🎯 Interactive Player Selection

🔍 Smart Search – Find players instantly by name

☑️ Checkbox Selection – Compare up to 4 players

🧭 Position Filter – Forward, Midfielder, Defender

⭐ Rating Filter – Minimum overall rating slider

🏆 Top 50 View – Highest-rated players matching filters

📈 Customizable Radar Plots

📊 35 FIFA Attributes – Choose any 6 metrics

🎨 Visual Controls – Line width & fill transparency

🌈 Color-Coded Players – Easy visual distinction

🧾 Player Cards – Snapshot of key stats

📊 Data Analysis Tools

📋 Interactive Data Table – Sortable & filterable

📈 Statistical Summaries – Metric averages & insights

🥇 Top 25 Rankings – By overall rating

💾 Export Options – Download plots (PNG) & data (CSV)

📚 Educational Content

📖 Metrics Guide – Explanation of all 35 FIFA attributes

🗄️ Database Documentation – Schema & table info

📐 Interpretation Help – How to read radar plots

🛠️ Technologies Used

R – Statistical computing

Shiny – Interactive web framework

fmsb – Radar chart visualization

dplyr – Data manipulation

DT – Interactive tables

RSQLite / DBI – SQLite database integration

shinythemes – UI styling

📦 Installation
Prerequisites

R (version 4.0+)

RStudio (recommended)

Required Packages
install.packages(c(
  "shiny",
  "fmsb",
  "dplyr",
  "shinythemes",
  "DT",
  "RSQLite",
  "DBI"
))

Setup

Clone the repository

git clone https://github.com/yourusername/soccer-player-radar.git
cd soccer-player-radar


Download the European Soccer Database

Source: Kaggle – European Soccer Database

Place database.sqlite in the project root directory

Run the application

library(shiny)
runApp()

📁 Project Structure
soccer-player-radar/
├── app.R                    # Main Shiny application
├── database.sqlite          # European Soccer Database (not included)
├── README.md                # Project documentation
└── screenshots/             # App screenshots
    ├── radar-plot.png
    ├── data-table.png
    └── analysis.png

💾 Database Schema

The app uses the European Soccer Database with key tables:

Table	Records	Description
Player	11,060	Player biographical information
Player_Attributes	183,978	FIFA ratings & attributes
Team	299	Team information
Match	25,979	Match results & statistics
📐 Available Player Metrics (35 Total)
⚽ Offensive

overall_rating, potential, finishing, shot_power, long_shots, volleys, penalties, positioning

🎯 Technical

crossing, short_passing, long_passing, dribbling, ball_control, curve, free_kick_accuracy, heading_accuracy

🏃 Physical

acceleration, sprint_speed, agility, reactions, balance, jumping, stamina, strength

🛡️ Defensive

marking, standing_tackle, sliding_tackle, interceptions, aggression

🧤 Goalkeeping

gk_diving, gk_handling, gk_kicking, gk_positioning, gk_reflexes

🚀 Usage Examples
Comparing Forwards

Filter position → Forward

Search: Messi, Ronaldo, Lewandowski

Metrics: Finishing, Shot Power, Dribbling, Positioning, Ball Control, Acceleration

Compare attacking profiles

Analyzing Midfielders

Filter position → Midfielder

Select: De Bruyne, Modrić, Kroos

Metrics: Short Passing, Long Passing, Ball Control, Dribbling, Stamina

Identify playmaking differences

Evaluating Defenders

Filter position → Defender

Select: Van Dijk, Ramos, Maldini

Metrics: Marking, Tackling, Interceptions, Strength, Heading Accuracy

Compare defensive styles

📊 Learning Outcomes

This project demonstrates:

✅ Statistical & exploratory data analysis

✅ Interactive data visualization

✅ SQLite database querying with R

✅ Shiny web app development

✅ UI/UX design for data exploration

✅ Large-scale data wrangling (183k+ records)

🎓 Use Cases

⚽ Sports analytics & scouting

📚 Academic research

🧠 Fantasy football decision-making

🎓 Teaching data visualization

🏋️ Player development analysis

🤝 Contributing

Contributions are welcome!

How to Contribute

Fork the repository

Create a feature branch

git checkout -b feature/AmazingFeature


Commit changes

git commit -m "Add AmazingFeature"


Push to GitHub

git push origin feature/AmazingFeature


Open a Pull Request

📝 License

This project is licensed under the MIT License.
See the LICENSE file for details.

🙏 Acknowledgments

Data Source: European Soccer Database (Kaggle)

FIFA Ratings: Official FIFA attributes (2008–2016)

R Community: Incredible open-source ecosystem

📧 Contact

Your Name
📧 Your Email
🔗 GitHub: https://github.com/yourusername/soccer-player-radar

💼 LinkedIn: Your LinkedIn Profile

⭐ Star this repository if you found it helpful!

🔮 Future Enhancements

Team-level analysis & comparison

Match performance trends

Player similarity recommendations

Temporal player development analysis

Position-specific metric presets

PDF export support

Advanced filters (age, league, nationality)

Mobile responsiveness

Built with ❤️ for soccer analytics enthusiasts
