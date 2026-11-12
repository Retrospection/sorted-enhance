@issue_1
Feature: Use Mac editing tools and system entry points
  Use a disposable macOS account. Record the app language, system language,
  time zone, notification settings, reference version and supported entry points.

  @notes_attachments
  Scenario Outline: Round-trip rich content
    Given a writable <item> with bold text, a checked line and an unchecked line
    When I attach a file containing "payload 42", save, relaunch and reopen the item
    Then formatting and both checklist states survive and the opened file contains "payload 42"
    When I remove the attachment and reopen the item
    Then the attachment is gone and the note and original file are intact

    Examples:
      | item           |
      | local task     |
      | calendar event |

  @notes_attachments @reference
  Scenario: Determine what belongs to the app and to Calendar
    Given the same writable calendar event in each test environment
    When I add an event note, a file and a drawing where supported
    And I inspect Calendar and the planner separately after relaunch
    Then the available drawing actions and content visible in each app match the reference Mac behavior

  @fast_entry
  Scenario: Correct a recognized date before saving
    Given the Mac uses English and it is Monday
    When I enter "Send invoice tomorrow at 8am" using quick entry
    And I change the recognized time to 09:30 before saving
    Then a single invoice task appears on Tuesday at 09:30 and none appears at 08:00

  @alerts
  Scenario Outline: Invalidate an obsolete alert
    Given notifications are enabled, Focus is off and a new task has an alert five minutes from now
    When I <change> before the alert fires and close the planner window
    Then no alert appears at the old time
    And <result>

    Examples:
      | change                                      | result                                               |
      | postpone the task and alert by five minutes | exactly one alert appears at the new time            |
      | complete the task                           | no alert for the completed task appears afterward     |

  @widgets @reference
  Scenario Outline: Refresh a widget and follow its link
    Given I record which <widget> variant is available in the Mac widget gallery
    And I configure the supported widget with a task visible in its day, list or tag
    When I rename the task in the app and allow the widget to refresh
    Then the new title replaces the old one
    When I activate the widget entry
    Then the app opens the matching task or day according to the recorded widget action

    Examples:
      | widget |
      | Today  |
      | List   |
      | Tag    |

  @shortcuts_links_sharing @reference
  Scenario Outline: Deliver an external action exactly once
    Given I record the supported Mac action and prepare a unique title or item link
    When I invoke <entry> once while the planner is closed, then repeat with fresh input while it is open
    Then each invocation has <outcome> and reopening the app does not replay it

    Examples:
      | entry                        | outcome                                             |
      | Add Task in Shortcuts        | one new task with the requested list, tags and time |
      | Add Event in Shortcuts       | one event with the requested duration and alert     |
      | a supported creation URL     | one new item with correctly decoded text            |
      | a supported item link        | the existing item open with no duplicate            |
      | the supported Share action   | one item containing the shared content              |
