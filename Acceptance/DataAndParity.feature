@issue_1
Feature: Preserve data and verify the Mac reference

  @icloud
  Scenario: Offline edits converge on two Macs
    Given two disposable Mac profiles use the same test iCloud account and have finished initial sync
    And both show tasks A, B and C in that order in a test list
    When I disconnect Mac A, complete A, attach a known file to B and move C first
    And I rename B on Mac B and reconnect Mac A
    Then both Macs eventually show A complete, C first and B renamed with the readable file
    When I delete C on Mac B and relaunch both apps after sync
    Then C is absent from both active lists and neither Mac has duplicate tasks

  @icloud @reference
  Scenario: Resolve concurrent changes to one field
    Given both Macs have synced the same task and are then disconnected
    When I give it different titles on each Mac and reconnect them in a recorded order
    Then both converge on one task and the same title after relaunch
    And I compare the winning value or conflict prompt with the reference using the same sequence

  @backup_restore
  Scenario: Recover a previous state from an automatic backup
    Given a disposable library with a dated task, note, readable attachment, folder, list and tags
    And I observe a completed automatic backup of this library
    When I edit the note, delete the attachment, move the list and restore that backup
    Then after relaunch the original note, date, attachment bytes, folder, list and tags match the saved fixture

  @backup_restore
  Scenario: Reject a damaged backup without partial writes
    Given a disposable library and a truncated copy of a backup with different content
    When I attempt to restore the truncated copy
    Then the app reports failure
    And every original task, relationship and attachment is still readable after relaunch

  @mac_inventory @reference
  Scenario: Discover Mac-only entry points and differences
    Given a fresh profile and the exact Sorted³ Mac version and build number
    When I walk through first run, sidebar, menus, settings and the item editor
    And I exercise appearance, date and time preferences, shortcuts, notifications and available import or export actions
    Then each observed action has an input, steps, expected outcome and version in the parity record
    And each newly discovered behavior has a corresponding acceptance case or documented platform difference

  @mac_inventory @settings_comparison @reference
  Scenario Outline: Compare observed Mac settings on a disposable profile
    Given Sorted³ 3.10 build 365 and the candidate each use a disposable Mac profile
    When I open Settings, locate <control> and perform <action>
    Then I record the result in each app after relaunch and any missing control

    Examples:
      | control                       | action                                                  |
      | appearance                    | switch between system and explicit theme                |
      | spacing and Inbox icon        | choose another value and inspect the sidebar and rows   |
      | week start, 24-hour and lunar | change each date preference and inspect the calendar    |
      | badge and overdue             | schedule a past task and inspect the badge              |
      | notification and sound       | change the lead and snooze on a new test alert          |
      | duration and time ruler       | set a default duration and reverse the ruler direction  |
      | Calendars and Reminders       | select a disposable calendar and import a test reminder |
      | iCloud and automatic backup   | enable each service and verify the fixture is captured  |
      | passcode                      | set a test code and reopen the protected profile        |
      | diagnostic export             | export a diagnostic file for the disposable profile     |
      | tutorial tasks                | add the tutorial list and locate its example tasks      |

  @completion @reference
  Scenario: Reconcile each Issue 1 item against the Mac build
    Given the reference inventory and the candidate build identifier
    When I compare the recorded outcomes of all feature cases on both builds
    Then each issue item links to its case results, reference version and candidate version
    And each difference has a reproduction and a disposition
    And each missing environment or unavailable action is identified separately from a pass
