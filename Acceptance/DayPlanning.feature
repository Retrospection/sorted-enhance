@issue_1
Feature: Capture tasks and plan a day on Mac
  Use a disposable macOS account, a writable test calendar and one read-only
  calendar. Use a 24-hour clock and the same time zone in both apps. Run each
  scenario with fresh test items. Times refer to one selected future weekday.

  @inbox
  Scenario: Edit a copy without changing its source
    Given an undated Inbox task "Draft" with the note "Outline"
    When I duplicate it and rename the copy "Send"
    Then the Inbox contains one "Draft" and one "Send"
    And both contain "Outline"
    When I cancel "Send", reopen it, complete it, and reopen it again
    Then only "Send" changes status at each step
    And both items are active in the Inbox after relaunch

  @daily_schedule
  Scenario: Read one day and navigate away and back
    Given today's items are an untimed task, a completed 09:00–09:30 task, a 10:00–11:00 event and a 10:30–11:30 task
    And tomorrow contains a different task
    When I open today's schedule
    Then I can distinguish the untimed item, completed work, 30-minute gap and 30-minute overlap
    And the timed items show their respective durations
    When I navigate to tomorrow and return using Today
    Then each day contains only its own items

  @calendar_events
  Scenario: Reflect calendar visibility, recurrence and external edits
    Given calendar A contains a timed meeting, an all-day holiday, an overnight event and a weekly series
    And read-only calendar B contains one appointment
    When I show both calendars
    Then the holiday has no invented start time and the overnight event appears on both affected days
    And the weekly meeting appears on its occurrence dates
    And the appointment cannot be written back to calendar B
    When I move one series occurrence in Calendar and refresh twice
    Then it appears once at its new time and is absent at its old time
    When I hide A
    Then only B's appointment and local tasks remain visible

  @calendar_events
  Scenario: Calendar permission is denied
    Given Calendar access is denied for the app in macOS settings
    When I create and schedule a local task and relaunch
    Then the local task retains its time without requiring calendar authorization

  @auto_schedule @milestone
  Scenario: Replan after a delay without moving the meeting or rewriting history
    Given a fixed meeting from 14:00 to 15:00
    And tasks "Outline" for 30 minutes and "Write" for 60 minutes in that order
    When I auto-schedule from 13:00 with no buffer
    Then "Outline" starts at 13:00 and "Write" starts at 15:00
    When I complete "Outline", replan from 15:30 and relaunch
    Then "Outline" is complete at 13:00, the meeting starts at 14:00 and "Write" starts at 15:30

  @auto_schedule @manual_scheduling
  Scenario: A locked task partitions the remaining time
    Given a locked task from 10:00 to 10:30 and two movable tasks of 30 and 45 minutes in that order
    When I schedule from 09:30 with no buffer
    Then the 30-minute task ends exactly at 10:00 and the 45-minute task starts at 10:30
    And the locked task retains its time and duration after relaunch

  @auto_schedule @reference
  Scenario Outline: Match the Mac scheduler at its boundaries
    Given I record the reference Mac version and set up <input> in both apps
    When I schedule both days from the same time
    Then task order, assigned times, omitted tasks and overflow feedback match the recorded reference outcome

    Examples:
      | input                                                      |
      | three 20-minute tasks and a configured 10-minute buffer    |
      | two tasks without explicit durations                      |
      | a 90-minute task with only 30 minutes left in the workday  |
      | two overlapping fixed meetings and one movable task       |

  @manual_scheduling
  Scenario: Change duration, clear a time and preserve manual order
    Given tasks A, B and C on one day
    When I set A to 10:00 for 45 minutes and drag C before B
    And I set a start time on B, clear it and relaunch
    Then A still occupies 10:00–10:45, B has no start time and C precedes B
