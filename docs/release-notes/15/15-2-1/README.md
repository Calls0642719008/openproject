---
title: OpenProject 15.2.1
sidebar_navigation:
    title: 15.2.1
release_version: 15.2.1
release_date: 2025-02-05
---

# OpenProject 15.2.1

Release date: 2025-02-05

We released OpenProject [OpenProject 15.2.1](https://community.openproject.org/versions/2170).
The release contains several bug fixes and a security related fix and we recommend updating to the newest version.
In these Release Notes, we will give an overview of important feature changes.
At the end, you will find a complete list of all changes and bug fixes.

<!--more-->

## Bug fixes and changes

<!-- Warning: Anything within the below lines will be automatically removed by the release script -->
<!-- BEGIN AUTOMATED SECTION -->

- Bugfix: Error on applying filter changes in Cost Reports \[[#60023](https://community.openproject.org/wp/60023)\]
- Bugfix: Project attributes of type list cannot be edited anymore \[[#60388](https://community.openproject.org/wp/60388)\]
- Bugfix: Background job to schedule new meeting instances failed \[[#60621](https://community.openproject.org/wp/60621)\]
- Bugfix: Missing debounce when searching for work packages in relations tab \[[#60649](https://community.openproject.org/wp/60649)\]
- Bugfix: Slow /api/v3/work\_packages/\*/available\_relation\_candidates \[[#60732](https://community.openproject.org/wp/60732)\]
- Bugfix: Date alerts blocking more important background jobs \[[#60856](https://community.openproject.org/wp/60856)\]
- Bugfix: RHEL: Can&#39;t install BIM edition \[[#60870](https://community.openproject.org/wp/60870)\]
- Bugfix: High DB load caused by date alert background jobs \[[#60932](https://community.openproject.org/wp/60932)\]
- Bugfix: Setting the user display format without a lastname breaks User custom fields with group values \[[#60976](https://community.openproject.org/wp/60976)\]
- Bugfix: Buttons can&#39;t fit on the Activity Tab for Russian and German \[[#61053](https://community.openproject.org/wp/61053)\]
- Bugfix: Label text in comment box is overflowing in German \[[#61088](https://community.openproject.org/wp/61088)\]
- Bugfix: HTML injection in device name \[[#61089](https://community.openproject.org/wp/61089)\]

<!-- END AUTOMATED SECTION -->
<!-- Warning: Anything above this line will be automatically removed by the release script -->

## Contributions

A big thanks to our Community members for reporting bugs and helping us identify and provide fixes.
This release, special thanks for reporting and finding bugs go to Boris Lukashev, Serg Baranov, Lars Briem, Andrey Dermeyko.

A special thanks goes out to [Kanitin Pholngam](https://github.com/meanknt) for responsible disclosure of a potential security vulnerability. Thank you for reaching out to us and your help in identifying this issue. If you have a security vulnerability you would like to disclose, please see our [statement on security](../../../security-and-privacy/statement-on-security/).
