@issue_1
Feature: Change several schedule items on Mac
  Start each scenario with four 10-minute tasks A through D at 09:00, 09:20,
  09:40 and 10:00 on Monday in the same list with the same tag.

  @magic_select
  Scenario Outline: Reorder a selection without changing its internal order
    When I select <selection> and move it after D
    Then the visible order is <order> and each task occurs exactly once

    Examples:
      | selection                  | order      |
      | the range B through C      | A, D, B, C |
      | A and C individually       | B, D, A, C |

  @time_ruler
  Scenario: Shift a group in fine and coarse increments
    When I select B and C and advance the Time Ruler five minutes
    Then B starts at 09:25 and C at 09:45
    When I move them back one hour
    Then B starts at 08:25 and C at 08:45
    And their durations and the start times of A and D are unchanged

  @time_ruler @reference
  Scenario: Adjust spacing between selected items
    Given I record whether and how the reference Mac app exposes Pinch Time
    When I spread and contract B and C with the supported Mac input
    Then the change in their separation matches the reference at each step
    And A and D keep their times
    And if the input is unavailable on Mac I record the version and platform difference

  @calendar_drawer
  Scenario Outline: Assign dates from each supported context
    Given B and C are selected in <view>
    When I assign Tuesday in the Calendar Drawer
    Then Tuesday contains B and C exactly once and Monday contains A and D at their original times
    And B and C retain their list and tag

    Examples:
      | view     |
      | list     |
      | tag      |
      | schedule |

  @mac_editing_controls
  Scenario: Undo and redo a batch edit from the keyboard
    When I focus B with the keyboard, extend the selection to C and move both to Tuesday using a menu command
    And I invoke Undo once
    Then both return to Monday at their original times
    When I invoke Redo once
    Then both move back to Tuesday and A and D remain on Monday
