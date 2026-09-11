import Foundation

nonisolated enum TodayCopy {
    static let navigationTitle = AppCopy.today
    static let readyToFocus = LocalizedCopy("Ready to focus")
    static let emptyDescription = LocalizedCopy(
        "Create a plan to start a focus session. Apple Intelligence is optional."
    )
    static let createPlan = LocalizedCopy("Create a plan")
    static let upNext = LocalizedCopy("Up next")
    static let done = LocalizedCopy("Done")
    static let openPlan = LocalizedCopy("Open plan")
    static let startFocus = AppCopy.startFocus
    static let searchGoogle = AppCopy.searchGoogle

    static func openPlan(named title: String) -> LocalizedCopy {
        LocalizedCopy(format: "Open \(title) plan", english: "Open \(title) plan")
    }
}

nonisolated enum PlansCopy {
    static let navigationTitle = AppCopy.plans
    static let emptyTitle = LocalizedCopy("No plans yet")
    static let emptyDescription = LocalizedCopy(
        "Create a manual plan. Generated plans can wait until Apple Intelligence is available."
    )
    static let createPlan = TodayCopy.createPlan
    static let active = LocalizedCopy("Active")
    static let archived = LocalizedCopy("Archived")
}

nonisolated enum SettingsCopy {
    static let navigationTitle = AppCopy.settings
    static let timer = AppCopy.timer
    static let notifications = AppCopy.notifications
    static let appleIntelligence = AppCopy.appleIntelligence
    static let privacy = LocalizedCopy("Privacy")
    static let startBreaksAutomatically = LocalizedCopy("Start breaks automatically")
    static let playTimerSounds = LocalizedCopy("Play timer sounds")
    static let generatedPlansHint = LocalizedCopy(
        "Generated plans start from Today or Plans, and you review every draft before it is saved."
    )
    static let privacyOverview = LocalizedCopy(
        """
        Goals, survey answers, generated plans, and focus history stay on this device. EaseFocus does not track you or use analytics.

        When Apple Intelligence is available, plan generation runs on device.
        """
    )

    static func focusMinutes(_ minutes: Int) -> LocalizedCopy {
        LocalizedCopy(format: "Focus minutes: \(minutes)", english: "Focus minutes: \(minutes)")
    }

    static func shortBreak(_ minutes: Int) -> LocalizedCopy {
        LocalizedCopy(format: "Short break: \(minutes)", english: "Short break: \(minutes)")
    }

    static func longBreak(_ minutes: Int) -> LocalizedCopy {
        LocalizedCopy(format: "Long break: \(minutes)", english: "Long break: \(minutes)")
    }

    static func sessionsBeforeLongBreak(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(
            format: "Sessions before long break: \(count)",
            english: "Sessions before long break: \(count)"
        )
    }
}

nonisolated enum OnboardingCopy {
    static let navigationTitle = LocalizedCopy("Welcome to EaseFocus")
    static let introduction = LocalizedCopy(
        "EaseFocus turns a goal into timed focus sessions. Allow these so the timer and generated plans can work fully."
    )
    static let notifications = AppCopy.notifications
    static let appleIntelligence = AppCopy.appleIntelligence
    static let continueAction = AppCopy.continueAction
}

nonisolated enum TaskCopy {
    static let start = LocalizedCopy("Start")
    static let startFocus = AppCopy.startFocus
    static let remove = AppCopy.remove
    static let markCompleted = LocalizedCopy("Mark completed")
    static let markNotCompleted = LocalizedCopy("Mark as not completed")
    static let completed = LocalizedCopy("Completed")
    static let notCompleted = LocalizedCopy("Not completed")
    static let moveUp = LocalizedCopy("Move task up")
    static let moveDown = LocalizedCopy("Move task down")
    static let removeTaskTitle = LocalizedCopy("Remove this task?")
    static let newTask = LocalizedCopy("New task")
    static let optionalSearchQuery = LocalizedCopy("Optional search query")

    static func deleteMessage(taskTitle: String) -> LocalizedCopy {
        LocalizedCopy(
            format: "“\(taskTitle)” will be deleted from the plan.",
            english: "“\(taskTitle)” will be deleted from the plan."
        )
    }

    static func estimatedSessions(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(format: "\(count) estimated sessions", english: "\(count) estimated sessions")
    }

    static func sessionCount(completed: Int, estimated: Int) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(completed)/\(estimated) sessions",
            english: "\(completed)/\(estimated) sessions"
        )
    }

    static func sessionCountWithBroken(completed: Int, estimated: Int, broken: Int) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(completed)/\(estimated) sessions · \(broken) broken",
            english: "\(completed)/\(estimated) sessions · \(broken) broken"
        )
    }
}

nonisolated enum PlanEditorCopy {
    static let plan = LocalizedCopy("Plan")
    static let title = LocalizedCopy("Title")
    static let details = LocalizedCopy("Details")
    static let taskTitle = LocalizedCopy("Task title")
    static let tasks = LocalizedCopy("Tasks")
    static let addTask = LocalizedCopy("Add task")
    static let cancel = AppCopy.cancel
    static let save = AppCopy.save
    static let regenerate = LocalizedCopy("Regenerate")
    static let reviewDraft = LocalizedCopy("Review draft")
    static let newPlan = LocalizedCopy("New plan")
    static let resourceSearchFooter = LocalizedCopy(
        "Resource search suggestions can be edited or removed. A query leaves EaseFocus only when you confirm Search Google."
    )
    static let reorderFooter = LocalizedCopy("Use the arrow buttons to set the task order.")
}

nonisolated enum PlanDetailCopy {
    static let navigationTitle = LocalizedCopy("Plan")
    static let planActions = LocalizedCopy("Plan actions")
    static let archive = LocalizedCopy("Archive")
    static let markCompleted = LocalizedCopy("Mark completed")
    static let tasks = PlanEditorCopy.tasks
    static let title = PlanEditorCopy.title
    static let details = PlanEditorCopy.details
    static let newTask = TaskCopy.newTask
    static let add = AppCopy.add
    static let resourceSearchFooter = LocalizedCopy(
        "Add a resource search when a Google query would help. Search Google opens in your browser after you confirm."
    )
    static let order = LocalizedCopy("Order")
}

nonisolated enum SurveyCopy {
    static let navigationTitle = PlanEditorCopy.newPlan
    static let goalPlaceholder = LocalizedCopy("What do you want to achieve?")
    static let goalHint = LocalizedCopy("This becomes the plan’s focus.")
    static let experience = LocalizedCopy("Current experience")
    static let experienceHint = LocalizedCopy("Used to keep tasks at the right difficulty.")
    static let beginner = LocalizedCopy("Beginner")
    static let someExperience = LocalizedCopy("Some experience")
    static let advanced = LocalizedCopy("Advanced")
    static let successPlaceholder = LocalizedCopy("What would make this plan successful?")
    static let successHint = LocalizedCopy("Helps the draft aim at a concrete outcome.")
    static let deadlineToggle = LocalizedCopy("I have a deadline")
    static let deadline = LocalizedCopy("Deadline")
    static let deadlineHint = LocalizedCopy("Optional. Used only to pace the work.")
    static let constraintsPlaceholder = LocalizedCopy("Preferences or constraints")
    static let constraintsHint = LocalizedCopy(
        "Optional. Examples: no evenings, keep sessions short, avoid public speaking."
    )
    static let createManually = LocalizedCopy("Create manually")
    static let generate = LocalizedCopy("Generate")
    static let stop = LocalizedCopy("Stop")
    static let cancel = AppCopy.cancel
    static let generating = LocalizedCopy("Generating a draft…")
    static let sessionsHint = LocalizedCopy("Keeps the plan sized to the time you actually have.")

    static func sessionsPerWeek(_ count: Int) -> LocalizedCopy {
        LocalizedCopy(
            format: "\(count) focus sessions a week",
            english: "\(count) focus sessions a week"
        )
    }
}

nonisolated enum PersistenceErrorCopy {
    static let title = LocalizedCopy("Couldn't open your data")
    static let preserved = LocalizedCopy(
        "EaseFocus could not open easefocus.store. Your store files were preserved."
    )
    static let retryHint = LocalizedCopy(
        "Quit any other EaseFocus copies and try again. If the problem continues, keep the store files and contact support."
    )
}

nonisolated enum NoticeCopy {
    static let openAppleIntelligence = LocalizedCopy("Open Apple Intelligence & Siri")
    static let openNotifications = LocalizedCopy("Open Notifications Settings")
}

nonisolated enum TimerNotificationCopy {
    static let appName = LocalizedCopy("EaseFocus")
    static let finished = LocalizedCopy("Your timer has finished.")
    static let breakFinished = LocalizedCopy("Break finished.")
    static let focusComplete = LocalizedCopy("Focus session complete.")
}
