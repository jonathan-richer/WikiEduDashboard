React           = require 'react'
ReactRouter     = require 'react-router'
Router          = ReactRouter.Router
TransitionGroup = require 'react-addons-css-transition-group'

Timeline        = require './timeline'
Grading         = require './grading'
Editable        = require '../high_order/editable'
Meetings        = require './meetings'

ServerActions   = require '../../actions/server_actions'
TimelineActions   = require '../../actions/timeline_actions'

CourseStore     = require '../../stores/course_store'
WeekStore       = require '../../stores/week_store'
BlockStore      = require '../../stores/block_store'
GradeableStore  = require '../../stores/gradeable_store'
TrainingStore   = require '../../training/stores/training_store'

getState = ->
  course: CourseStore.getCourse()
  weeks: WeekStore.getWeeks()
  blocks: BlockStore.getBlocks()
  gradeables: GradeableStore.getGradeables()
  all_training_modules: TrainingStore.getAllModules()
  editable_block_ids: BlockStore.getEditableBlockId()
  editable_week_id: WeekStore.getEditableWeekId()

# Returns string describing weekday meetings for each week
# Ex: ["(Mon, Weds, Fri)", "(Mon, Weds)", "()", "(Mon, Weds, Fri)"]
weekMeetings = (recurrence) ->
  return unless recurrence?
  course_weeks = Math.ceil(recurrence.endDate().diff(recurrence.startDate(), 'weeks', true))
  unless recurrence.rules? && recurrence.rules[0].measure == 'daysOfWeek' && Object.keys(recurrence.rules[0].units).length > 0
    return null

  meetings = []
  [0..(course_weeks)].forEach (week) =>
    week_start = moment(recurrence.startDate()).startOf('week').add(week, 'weeks')
    ms = []
    [0..6].forEach (i) =>
      added = moment(week_start).add(i, 'days')
      if recurrence.matches(added)
        ms.push moment.localeData().weekdaysShort(added)
    if ms.length == 0
      meetings.push '()'
    else
      meetings.push "(#{ms.join(', ')})"
  return meetings


TimelineHandler = React.createClass(
  displayName: 'TimelineHandler'
  componentWillMount: ->
    ServerActions.fetch 'timeline', @props.course_id
    ServerActions.fetchAllTrainingModules()
  _cancelBlockEditable: (block_id) ->
    BlockStore.restore()
    BlockStore.cancelBlockEditable(block_id)
  _cancelGlobalChanges: ->
    BlockStore.restore()
    BlockStore.clearEditableBlockIds()
  saveTimeline: (editable_block_id=0) ->
    toSave = $.extend(true, {}, @props)
    TimelineActions.persistTimeline(toSave, @props.course_id)
    WeekStore.clearEditableWeekId()
    if editable_block_id > 0
      BlockStore.cancelBlockEditable(editable_block_id)
    else
      BlockStore.clearEditableBlockIds()

  render: ->
    outlet = React.cloneElement(@props.children, {key: 'wizard_handler', course: @props.course, weeks: @props.weeks, open_weeks: @props.course.open_weeks}) if @props.children

    if @props.course.weekdays?
      meetings = moment().recur(@props.course.timeline_start, @props.course.timeline_end)
      weekdays = []
      @props.course.weekdays.split('').forEach (wd, i) ->
        return unless wd == '1'
        day = moment().weekday(i)
        weekdays.push(moment.localeData().weekdaysShort(day))
      meetings.every(weekdays).daysOfWeek()
      @props.course.day_exceptions.split(',').forEach (e) ->
        meetings.except(moment(e, 'YYYYMMDD')) if e.length > 0

    <div>
      <TransitionGroup
        transitionName="wizard"
        component='div'
        transitionEnterTimeout={500}
        transitionLeaveTimeout={500}
      >
        {outlet}
      </TransitionGroup>
      <Timeline
        loading={@props?.loading}
        course={@props?.course}
        weeks={@props?.weeks}
        week_meetings={weekMeetings(meetings)}
        editable_block_ids={@props?.editable_block_ids}
        editable_week_id={@props.editable_week_id}
        controls={@props?.controls}
        saveGlobalChanges={@saveTimeline}
        saveBlockChanges={@saveTimeline}
        cancelBlockEditable={@_cancelBlockEditable}
        cancelGlobalChanges={@_cancelGlobalChanges}
        all_training_modules={@props.all_training_modules}
      />
      <Grading {...@props} />
    </div>
)

module.exports = Editable(TimelineHandler, [CourseStore, WeekStore, BlockStore, GradeableStore, TrainingStore], TimelineActions.persistTimeline, getState)
