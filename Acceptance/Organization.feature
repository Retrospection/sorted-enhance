@issue_1
Feature: Organize and recover tasks on Mac

  @folders_lists_tags
  Scenario: Preserve task identity across organization changes
    Given folders Home and Work, lists Alpha and Beta in Home, and a task in Beta with tags Red and Blue
    When I reorder Beta before Alpha, rename Beta to Projects and move it to Work
    Then the task appears in Work under Projects and in both tag filters
    When I rename the task through the Red filter
    Then the Blue filter and Projects show the new title once and Home no longer lists Projects

  @search_history_trash
  Scenario: Recover the same item through search, history and trash
    Given two tasks titled "Review" in different lists, one with the note "Agenda" and a 14:00 start
    When I search for "Review" and open the result for the task with "Agenda"
    Then its detail shows the correct list and start time
    When I complete that task and cancel the other
    Then History shows each under its correct status
    When I delete the completed task, restore it from Trash and relaunch
    Then exactly one restored task has its original note, list and start time

  @repeating_tasks @reference
  Scenario Outline: Preserve occurrence and series boundaries
    Given identical repeat rules in both apps for <case>
    When I perform <action> and inspect the previous and next three occurrences after relaunch
    Then dates, local times, completion state and occurrence count match the recorded Mac reference
    And unrelated series are unchanged

    Examples:
      | case                                    | action                                 |
      | weekly Monday task                      | complete this occurrence               |
      | weekly Monday task                      | edit this occurrence only              |
      | weekly Monday task                      | change the series rule to Tuesday      |
      | daily task                              | skip one occurrence                    |
      | monthly task starting January 31        | advance through February and March     |
      | 09:00 daily in America/New_York         | cross the spring and fall DST changes  |
      | daily task last opened five days ago    | reopen with five missed occurrences    |

  @reorganize_merge @reference
  Scenario: Split selected note lines and merge the results
    Given a dated, tagged task with three distinct lines, a checked checklist item and an attached file
    When I extract the second and third lines with Reorganize in both apps
    Then the resulting titles, order, source note, checklist state and item count match the Mac reference
    When I merge those items in a known order and relaunch
    Then the surviving items, text order, date, tags and readable attachments match the reference
