---
sidebar_navigation:
  title: Project overview
  priority: 900
description: Learn how to configure a project overview page
keywords: project overview page
---

# Project overview

The **Project overview** page is a dashboard with important information about your respective project(s). This page displays all relevant information for your team, such as members, news, project description, work package reports, or project status.

| Topic                                                        | Content                                                      |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| [What is the project overview?](#what-is-the-project-overview) | What can I do with the project overview page?                |
| [Project life cycle](#project-life-cycle)                    | What is the project life cycle?                              |
| [Project attributes](#project-attributes)                    | What are project attributes and how can I use them?          |
| [Mark project as a favorite](#mark-a-project-as-favorite)    | How can I mark a project as favorite?                        |
| [Archive a project](#archive-a-project)                      | How can I archive a project from the project overview page?  |
| [Widgets](#widgets)                                          | What are widgets, and how can I add them to my project overview page? |
| [Project status](#project-status)                            | Set your project status                                      |
| [Available project overview widgets](#available-project-overview-widgets) | What kind of widgets can I add to the project overview?      |
| [Resize and reorder widgets](#resize-and-reorder-widgets) | How can I re-order or re-size the widgets?                   |
| [Remove widgets](#remove-widgets-from-project-overview-page)  | How can I remove widgets from the project overview page?     |

## What is the project overview?

The project overview is a single dashboard page where all important information of a selected project can be displayed. The idea is to provide a central repository of information for the whole project team. 

Project information is added to the dashboard as either [project attributes](#project-attributes) or [widgets](#widgets). 

Open the project overview by navigating to **Overview** in the project menu on the left.

![Project overview page for a specific project in OpenProject](openproject_user_guide_project_overview.png)

## Project life cycle 

**Project life cycle** is an overview of project phases and phase gates, which offers a clear view of where each project stands within its defined timeline. 

Project phases are managed in the system administration and can be enabled or disabled individually in the settings of each project. This allows for defining multiple life cycle variants within the system. For example, a detailed life cycle for complex projects and a simplified one for smaller or less structured projects.

On each project's **overview page**, you can find a section called **project life cycle**. This section appears in the side panel above the **project attributes** and shows the dates configured for each phase and gate of the current project. 

> [!TIP]
>
> If all phases and gates are disabled for a project, the project lifecycle section is hidden from the overview page.

![Project life cycle phases displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_project_life_cycle.png)

### Schedule project phases

Project phases must follow specific rules for setting and adjusting dates. The system automatically schedules phases based on the input provided, enforcing correct order, preventing overlaps and gaps, and preserving durations where possible. Each subsequent phase starts on the next working day after the previous one ends."

For each of the active project phases, you can define a date range. To set or manage the date range click that date range (it will be empty initially) and set the date with an OpenProject date picker. 

> [!NOTE]
>
> Keep in mind that editing the date range of project phases requires the *Edit project phases* permission. 
> Viewing the project life cycle is also permission-controlled: without the *View project phases* permission, phases won't appear in the project overview, project list, work package filters, or on the work package view itself.

![Edit date range for project phase on a project overview page in OpenProject](openproject_user_guide_project_overview_project_life_cycle_edit_date_range.png)

Use the guidelines below to understand how phase and gate scheduling behaves.

#### Basic rules

- A phase is only considered fully defined when both a start and finish date are set. While it's possible to enter just one of the two (typically as a temporary state), such phases will not appear with dates in the overview. This allows flexibility when, for example, only the start date is known initially, but full definition is expected to follow shortly.
- The start date must be on or before the end date.
- The minimum duration of a phase is one day (start and end date can be the same).
- There is no maximum duration for a phase.
- Phases cannot overlap with one another.
- Gaps between phases and gates are not allowed.

#### Phase gates and constraints

- Gates are always positioned at the start or end of a phase and follow the phase's dates.

  - You cannot set gate dates independently — adjusting the phase's start or finish date will automatically move the corresponding gate.

    - Phase gates are never placed inside the phase duration but always at its borders.
    - Phase gates never overlap or share the same date with other gates.

  - **Phases and phase gates will follow the order predefined in the system administration** (e.g., *Initiating* must come before *Closing*). Dates for a subsequent phase cannot be before those of any preceding phase. The automatic scheduling enforces this as well.

- Project phases not activated in a project will not be considered at all with regards to constraints. 
  - **Child projects** are **not restricted** by the lifecycle dates of their parent project.

#### Automatic scheduling behavior

- **Scheduling occurs automatically** and without user confirmation when possible.
- When the **finish date of a phase changes**:
  - The **next active phase’s start date** is updated to the **next working day**. This can mean that the subsequent phase is moved into the future or into the past depending on the direction the preceding phase's finish date moved.
  - If the next phase has a **duration** (a phase will get a duration whenever start and finish date are set), its **finish date is adjusted** to preserve it (based on working days).
  - **Scheduling continues down the chain** of phases until no further adjustments are needed.

#### Missing or partial dates

- Scheduling begins **as soon as enough dates are defined**, even if not all phases have dates.
- If a user **removes the finish date** of a phase, the **start date of the successor** phase is preserved to maintain its duration.

#### Constraints and errors

- If a phase is shortened, subsequent phases are moved backwards in time.
- Setting a finish date that is **before the start date** results in an **error**. The start date is **not auto-adjusted**, and duration is not preserved in this case.

#### Inactive phases

- **Inactive phases are ignored** during scheduling.
- The next **active** phase (based on the order defined in the administration) is treated as the logical successor.
- When a phase is **deactivated**, its dates remain unchanged, and the scheduling continues from the following active phase.

#### Activating or deactivating phases

- When a phase is **activated**:
  - If the phase has a defined duration (both start and finish dates set), the system may adjust the dates to prevent gaps or overlaps.
  - This can trigger rescheduling of succeeding phases.
- When a phase is **deactivated**:
  - Its dates are preserved.
  - Scheduling will skip this phase and move directly to the next active phase.

> [!NOTE]
> Activating or deactivating phases requires the *Select project phases* permission.

#### Other scheduling triggers

- **Changes to non-working days** (added or removed) will reschedule all affected phases across all projects to **preserve duration**.
- **Modifications in global phase configuration** (adding, deleting, reordering) do **not** immediately reschedule existing projects.
- However, the **first user interaction** with a lifecycle after such changes will trigger a rescheduling to preserve phase durations.

## Project attributes

**Project attributes** are a set of project-level custom fields that let you display certain types of information relevant to your project.

You will see a list of all available project attributes in a pane on the right side of your Project overview page. They may be grouped in sections.

> [!TIP]
> Your view of the project attributes may vary depending on your  [roles and permissions in OpenProject](../../system-admin-guide/users-permissions/roles-permissions/). 
> The project attributes are visible for users with the **View project attributes** permission enabled. The editing icons are visible for users with the **Edit project attributes** permission.

![Project overview page showing project attributes on the right side](openproject_user_guide_project_overview_project_attributes_section_new.png)

To edit the value of any visible project attribute, simply click on that value. A modal will be displayed with all the attributes in that section.

![Edit a project attribute section on project overview page](openproject_user_guide_project_overview_project_attributes_section_edit_new.png)

Edit the values for each project attribute and click the **Save** button to confirm and save your changes.

> [!NOTE]
> If you are an instance admin and would like to create, modify or add project attributes, please read our [admin guide to project attributes](../../system-admin-guide/projects/project-attributes).

### Project attribute settings 

To adjust the the project attribute settings for a specific project click the **More** (three dots) icon and select *Manage project attributes*. This will lead you directly to the [project attribute settings](../projects/project-settings/project-attributes/).

![Link to project attribute settings from project overview page in OpenProject](openproject_user_guide_project_overview_project_attributes_settings.png)

> [!NOTE]
> This option is always available to instance and project administrators. It can also be activated for specific roles by enabling the *select_project_attributes* permission for that role via the [Roles and permissions page](../../system-admin-guide/users-permissions/roles-permissions/) in the administrator settings.

## Mark a project as favorite

You can mark the project as a *Favorite* by clicking the **Favorite** (star) icon in the upper right corner. The icon color will change to yellow and the project will be marked as favorite both on the overview page and in the projects list. Read more about [project lists](../projects/project-lists/). 

![Mark a project as favorite in OpenProject](openproject_user_guide_project_overview_mark_favorite.png)

To remove a project from favorites click the **Favorite** icon again. 

## Archive a project

You can archive a project directly from the project overview page. To do that click the **More** (three dots) icon and select *Archive project*.

![Archive a project on the project overview page in OpenProject](openproject_user_guide_project_overview_archive_project.png)

> [!NOTE]
> This option is always available to instance and project administrators. It can also be activated for specific roles by enabling the *archive_project* permission for that role via the [Roles and permissions page](../../system-admin-guide/users-permissions/roles-permissions/) in the administrator settings.

You can also archive a project under [project settings](../projects/project-settings/project-information/#archive-a-project) or in a [projects list](../projects/project-lists/). 

## Widgets

**Widgets** are small blocks of information that you can customize to display pertinent project information (such as project description, status, work package lists or graphs). You can add and remove multiple widgets, re-order them and resize them to your liking.

<video src="https://openproject-docs.s3.eu-central-1.amazonaws.com/videos/OpenProject-Quick_guide-Widgets.mp4"></video>

To add a widget to the project overview, click the green **+Widget** button. Alternatively, hover around the existing widgets and click the **+** icon that will appear automatically. 

![Add a widget on the project overview page in OpenProject](openproject_user_guide_project_overview_add_widget_button.png)

Click the **+** icon and choose which kind of widget you want to add.

![A list showing available widgets to be added to a project overview page in OpenProject](openproject_user_guide_project_overview_widget_list.png)


## Available project overview widgets

You can add various widgets to your project overview.

### Project description

The project description widget adds the project description to your project overview.

The description can be added or changed in the [project settings](../projects/project-settings).

![Project description widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_project_project_description_widget.png)

### Project status

Add your project status as a widget to display at a glance whether your project is on track, off track or at risk. You can set your project status and give a detailed description.

First, select your project status from the drop-down. You can choose between:

- On track
- Not set
- At risk
- Off track
- Not started
- Finished
- Discontinued

![Project status widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_project_project_status_widget.png)

Add a **project status description** and further important information, such as project owner, milestones and other important links or status information.

### Project members widget

You can add a widget which displays all project members and their corresponding role for this project on the project overview page. This includes both groups and users (placeholders or registered).

![Project members widget in OpenProject](openproject_user_guide_project_overview_project_members_widget.png)

You can [add members to your project](../../getting-started/invite-members/) via the green **+ Member** button in the bottom left corner.

The **View all members** button displays the list of project members that have been added to your project. Members can be individuals as well as entire groups.

### Subprojects

The subprojects widget lists all subproject of the respective project on the overview. You can directly open a subproject via this link.

![Subprojects widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_project_subprojects_widget.png)

The widget only links the first subproject hierarchy and not the children of a subproject.

To edit the project hierarchy, go to the [project settings](../projects/project-settings).

### Calendar widget

The calendar widget displays your current work packages in a calendar. It shows work packages that are being worked on at the current date. The maximum number of displayable work packages is 100.

![Calendar widget on a project overview page in OpenProject](openproject_user_guide_project_overview_calendar_widget.png)

### Custom text widget

Within the custom text widget you can add any project information which you want to share with your team, e.g. links to important project resources or work packages, filters, specifications.

You can also add files to be displayed or attached to your project overview.

![Custom text widget on a project overview page in OpenProject](openproject_user_guide_project_overview_custom_text_widget.png)

### News widget

Display the latest project news in the news widget on the project overview page.

![News widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_news_widget.png)

### Spent time widget

The spent time widget lists the **spent time in this project for the last 7 days**.

![Spent time widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_project_spent_time_widget.png)

Time entries link to the respective work package and can be edited or deleted. To have a detailed view on all spent time and costs, go to the [Cost reporting](../time-and-costs/reporting/) module.

### Work package graph widgets

The work package graph widgets display information about the work packages within a project. They can be displayed in different graph views, such as a bar graph or a pie chart.

![Work packages graph widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_work_packages_graph_widget.png)

**Configure the work package graph**

You can filter the work packages to be displayed in the graph according to the [work packages table configuration](../work-packages/work-package-table-configuration/).

To configure the work package graph, click the three dots icon in the top right corner and select **Configure view**.

![Configure widgets view on a project overview page in OpenProject](openproject_user_guide_project_overview_configure_widget.png)

Select the **Axis criteria** to be displayed on the axis of the graph, e.g. Accountable, Priority, Status, Type.

![Configure axis criteria for a work packages widget on a project overview page in OpenProject](openproject_user_guide_project_overview_axis_criteria_widget.png)

Next, select the **Chart type** how the work package information shall be displayed, e.g. as a bar graph, a line, a pie chart.

**Filter** the work packages for your chart.

Click the Filter tab in order to configure the work packages to be displayed, e.g. only work packages with the priority "high".

![Configure filters for a work packages widget on a project overview page in OpenProject](openproject_user_guide_project_overview_filter_criteria_widget.png)

Click the **Apply** button to save your changes.

If you want to replicate the widgets shown in the example in the screen-shot above:

- For the "Assignees" graph please choose the widget "work packages overview" and change to "assignees".
- For the Work packages status graph please select "work package graph", click the three dots icon in the upper right corner of the widget, choose "configure view", then choose "status" as axis criteria and "pie chart" as chart type.
- For the Work package progress graph please select "work package graph", click the three dots icon in the upper right corner of the widget, choose "configure view", then choose "% Complete" as axis criteria and "line" as chart type.

### Work package overview widget

The work package overview widget displays all work packages in a project differentiated by a certain criteria.

![Work packages overview widget displayed on a project overview page in OpenProject](openproject_user_guide_project_overview_wp_overview_widget.png)

You can display the graph according to the following criteria:

* Type
* Status
* Priority
* Author
* Assignee

![Dropdown menu showing criteria for the work package overview widget on a project overview page in OpenProject](openproject_user_guide_project_overview_wp_widget_criteria.png)

The widget lists all **open** and all **closed** work packages according to this criteria.

### Work package table widget

The work package table widget includes a work package table to the project overview. The work package table can be filtered, grouped, or sorted according to the [work package table configuration](../work-packages/work-package-table-configuration/), e.g. to display only work packages with the priority "High".

![Work packages table widget on a project overview page in OpenProject](openproject_user_guide_project_overview_wp_table_widget.png)

## Resize and reorder widgets

To **reorder** a widget, click the dots icon on the upper left hand corner and drag the widget with the mouse to the new position.

To **resize** a widget, click the grey icon in the lower right hand corner of the widget and drag the corner to the right or left. The widget will resize accordingly.

![Resize a widget on a project overview page in OpenProject](openproject_user_guide_project_overview_resize_widget.gif)

## Remove widgets from project overview page

To remove a widget from the project overview page, click the three dots icon at the top right corner of the widget and select **Remove widget**.

![Remove a widget from a project overview page in OpenProject](openproject_user_guide_project_overview_remove_widget.png)
