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

  @completion @reference
  Scenario: Reconcile each Issue 1 item against the Mac build
    Given the reference inventory and the candidate build identifier
    When I compare the recorded outcomes of all feature cases on both builds
    Then each issue item links to its case results, reference version and candidate version
    And each difference has a reproduction and a disposition
    And each missing environment or unavailable action is identified separately from a pass
