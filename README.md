# Thru-Hike Tracker

Thru-Hike Tracker is an app designed to allow thru-hikers to track their hikes, view statistics based on daily mileage entries, keep a journal, and update friends and family along the way. Existing hike-tracking apps do not allow users to keep track of on-trail vs off-trail miles, alternate routes, or skips, but Thru-Hike Tracker will allow users to accurately document their hike even when things don't go as planned.

## Progress Log

### Day To Day Progress and Goals
**Feb 4, 2025**


Completed:
* Fixed alternate route data table and model logic to account for multi day alternates and daily alternate entries
    * Created new file to store alternate route model in
    * Added option to mark whether a day started or ended on an alternate route
* Changed day-level calculations to take place in database service since they will be stored and queried
* Combined optional classes into one for simplicity (data entry model)
* Created gear/shoe model
    * Created distinct gear_service.dart file and created all CRUD operations for gear

TODO:
* Delegate the rest of database_helper.dart tables into separate files with CRUD operations (make alternate service, metadata service)
    * Think about what would go in user_service.dart. I think it would be used for calculating lifetime stats. Get data from all trail journals
* Try to test some of the code? VScode says no syntax errors so far


**Feb 2, 2025**


Completed:
* Completed initial draft of data tables to be stored (database_helper.dart)
* Set up structure for creating formulas for user to choose form
* Created empty files to delegate code into (move some functions from database_helper to formula_service, trail_journal_service, and user_service)
* Removed several bonus info fields from data entries since any users who want those fields can add them as custom

TODO:
* ~~Define gear/shoe model~~
* ~~Add option in alternate route data model for start/end location on this alternate (yes or no)~~


*Began documenting February 2nd, 2025*

### Setting Up App

**Jan 22-28, 2025**
* Set up initial draft of data models with JSON functions
* Set up database services for local storage system using SQLite
* Brainstormed how database schema will work as models increase in complexity

**Jan 20, 2025**
* Initial commit
* Main.dart as default initial app provided by flutter

**Jan 16-19, 2025**
* Decided Flutter would be best based on my limited experience with app development and goal of producing app relatively quickly
* Installed Flutter and VSCode and prepared computer for the project

### Initial App Idea
**September to December 2024**
* Recovered from trail
* Did not work on app, but decided to make it a goal for Spring 2025
* Decided I would need to start from scratch using Flutter or React Native to make it possible for people to access

**April to September 2024**
* Hiked 2500 miles on the Pacific Crest Trail, tracking everything using my spreadsheet, Hiker's Logbook, and Garmin GPS/Strava
* Desired to integrate functionalities from all methods into one
* Had trouble tracking total mileage including alternate routes including side trails and trail closures
* Ended up with a not quite accurate summary of my hiking stats
* Discovered other hikers had similar issues with tracking

**April 2024**
* Finalized spreadsheet for hike tracking and predicting. Began using existing hike tracking app (Hiker's Logbook)
* Did not progress on streamlit app in time for my hike

**March 2024**
* Created spreadsheet to track thru-hike
* Complexity of spreadsheet inspired idea for thru hike tracker app
* Set up basic data entry and trail data structure using Python and Streamlit package (in archived thru-hike-tracker repo)


.


### Eventual TODOs
**Broad**
* Once data tables are set up, design some graphs and visuals to track progress!
* Allow users to store photos with each journal entry
* Allow users to export entries and summaries based on date ranges
    * For example, export week 1 stats into an email to send to friends and family
* Allow users to export infographic-like images summarizing stats, for social media/sharing purposes
* Get data on hiker speed on different sections of different trails to model speed over time and across sections
    * Eventually try to model the nonlinear speed changes to create a predictive feature
    * Hikers could input a goal end date, and I could use data to determine when they should try to reach certain mile markers to stay on track (I created a simple model like this in a spreadsheet and it worked really well for predicting when I would reach certian towns on my hike)
    * Give users option to share mileage data to help build this model?
* Allow option to track bike routes. Data models would be slightly different (For example, wouldn't track shoes)
* Allow users to enter past hikes completed without individual daily entries, so they can hike lifetime miles even if they have completed hikes without tracking them daily on this app

**Specific**
* Create separate files for initial app idea and current progress, just link to them in README
* onupgrade in case I ever need to adjust schema?
* ~~Need to have option for start/end location to be on the alternate route~~
* Get section mile markers for each trail, and determine user's section based on mileage entry
* Allow user to toggle between imperial and metric
* User custom fields: Have ideas appear since I'm not explicitly defining them in bonus info anymore (# showers, trail magic, etc)
* Once user has entered specific wildlife sighting, provide it as an option in future entries (as opposed to custom animals each time)
    * For example, if someone enters they say 1 bear, provide bear as an option for future wildlife sightings
* Home page with entries: list view, feed view, and calendar view options
