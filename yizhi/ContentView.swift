//
//  ContentView.swift
//  yizhi
//
//  Created by Devon Crebbin on 17/12/2024.
//

import SwiftUI
import SwipeActions
import UserNotifications

// Helper extension
extension Calendar {
  fileprivate func startOfYear(for year: Int) -> Date {
    date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
  }
}

struct HalftonePattern: View {

  var isDarkMode: Bool {
    UITraitCollection.current.userInterfaceStyle == .dark
  }

  let rows: Int = 10
  let columns: Int = 40

  var body: some View {
    GeometryReader { geometry in
      let dotSize = min(
        geometry.size.width / CGFloat(columns),
        geometry.size.height / CGFloat(rows))

      ForEach(0..<rows, id: \.self) { row in
        ForEach(0..<columns, id: \.self) { column in
          Circle()
            .fill(isDarkMode ? Color.white : Color.black)
            .frame(
              width: dotSize * getDotScale(row: row),
              height: dotSize * getDotScale(row: row)
            )
            .position(
              x: CGFloat(column) * (geometry.size.width / CGFloat(columns - 1)),
              y: CGFloat(row) * (geometry.size.height / CGFloat(rows - 1))
            )
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: 70)
    .background(Color.clear)
    .clipped()
  }

  private func getDotScale(row: Int) -> CGFloat {
    let progress = CGFloat(row) / CGFloat(rows)
    return 1.0 - progress
  }
}

struct ContentView: View {

  var isDarkMode: Bool {
    UITraitCollection.current.userInterfaceStyle == .dark
  }

  struct Task: Decodable, Encodable {
    var id: String
    var name: String
    var completed: Bool
    var createdAt: Date
    var deletedAt: Date?
    var isEditing: Bool = false
    var editingName: String = ""
  }

  struct ContributionData: Decodable, Encodable {
    var dictionary: [String: [String: Task]] = [:]
  }

  @State var newTaskName = ""

  @State var currentDate: Date = Date()
  let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd-MM-yyyy"
    return formatter
  }()

  let calendar = Calendar.current
  let today = Date()

  @State var savedData: [String: [String: Task]] = [:]

  @State var savedTasks: [String: Task] = [:]

  @State var tasks: [String: Task] = [:]
  @State var contributionArray: [Double] = Array(repeating: 0.0, count: 366)

  @State private var notificationsEnabled = false

  private func setupNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      DispatchQueue.main.async {
        self.notificationsEnabled = granted
        if granted {
          print("Notification permission granted")
          // Register for remote notifications
          UIApplication.shared.registerForRemoteNotifications()
        } else {
          print("Notification permission denied")
        }
      }
    }
  }

  func loadData() {
    let defaults = UserDefaults.standard
    let startOfDay = calendar.startOfDay(for: currentDate)
    let todayString = dateFormatter.string(from: startOfDay)

    // Load contribution data
    if let retrievedData = defaults.data(forKey: "data"),
      let decodedContributionData = try? JSONDecoder().decode(
        ContributionData.self, from: retrievedData)
    {
      savedData = decodedContributionData.dictionary
    }

    if let retrievedTasksData = defaults.data(forKey: "tasks"),
      let decodedTasks = try? JSONDecoder().decode(
        [String: Task].self, from: retrievedTasksData)
    {
      tasks = decodedTasks
      savedTasks = decodedTasks
    }

    tasks = tasks.filter { id, task in
      task.deletedAt != nil
        ? (calendar.startOfDay(for: task.deletedAt!) > startOfDay
          && calendar.startOfDay(for: task.createdAt) <= startOfDay)
        : calendar.startOfDay(for: task.createdAt) <= startOfDay
    }

    tasks = Dictionary(
      uniqueKeysWithValues: tasks.sorted(by: { $0.value.createdAt < $1.value.createdAt }))

  }

  func calculateContribution() {
    var newContributionArray = Array(repeating: 0.0, count: 366)

    // Use the existing calendar instance from the class
    let today = Date()
    let startOfYear = calendar.date(
      from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
    let year = calendar.component(.year, from: today)

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"

    var totalContribution = 0.0

    for dayOffset in 0..<366 {
      if let date = calendar.date(
        byAdding: .day, value: dayOffset,
        to: calendar.startOfYear(for: year))
      {
        let dateString = dateFormatter.string(from: date)
        let startOfDay = calendar.startOfDay(for: date)

        if let filteredTasks = savedData[dateString]?.filter({ id, task in
          task.deletedAt != nil
            ? (calendar.startOfDay(for: task.deletedAt!) > startOfDay
              && calendar.startOfDay(for: task.createdAt) <= startOfDay)
            : calendar.startOfDay(for: task.createdAt) <= startOfDay
        }) {

          let availableTasks = savedTasks.filter { id, task in
            task.deletedAt != nil
              ? (calendar.startOfDay(for: task.deletedAt!) > startOfDay
                && calendar.startOfDay(for: task.createdAt) <= startOfDay)
              : calendar.startOfDay(for: task.createdAt) <= startOfDay
          }

          let completedCount = filteredTasks.filter { id, task in
            task.completed
          }.count

          let percentage =
            availableTasks.isEmpty
            ? 0.0 : (Double(completedCount) / Double(availableTasks.count)) * 100.0

          print(
            "Date: \(dateString), Available tasks:", availableTasks.count, "Completed tasks:",
            completedCount, "Percentage:", percentage)

          totalContribution += percentage
          newContributionArray[dayOffset] = percentage
        }
      }
    }
    contributionArray = newContributionArray
  }

  @State var contributionData: ContributionData = ContributionData()

  func addTask() {
    print("Adding task: \(newTaskName), created at: \(currentDate)")
    let id = UUID().uuidString
    tasks[id] = Task(
      id: id,
      name: newTaskName, completed: false, createdAt: currentDate,
      deletedAt: nil
    )
    saveTasksData()
    newTaskName = ""
  }

  func saveContributionData() {
    let defaults = UserDefaults.standard
    print("Saving contribution data:", savedData)
    let encoded = try? JSONEncoder().encode(ContributionData(dictionary: savedData))
    defaults.set(encoded, forKey: "data")
  }

  func saveTasksData() {
    let defaults = UserDefaults.standard

    print("Saving tasks:", tasks)
    let encoded = try? JSONEncoder().encode(tasks)
    defaults.set(encoded, forKey: "tasks")
  }

  private func loadContributionData() {
    calculateContribution()
  }

  func addTaskView() -> some View {
    HStack {
      TextField("Add a task", text: $newTaskName)
        .font(.system(size: 20, design: .serif))
        .textFieldStyle(.plain)
        .padding()
        .tint(isDarkMode ? Color.white : Color.black)
        .background(isDarkMode ? Color.black : Color.white).onSubmit {
          addTask()
        }
      Button(action: {
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
          for: nil)
        print("Adding task: \(newTaskName), created at: \(Date())")
        addTask()
      }) {
        Text("ADD")
          .foregroundColor(isDarkMode ? Color.white : Color.black)
          .font(.system(size: 20, design: .serif))
      }
    }.padding(.horizontal, 25)
  }

  func singleTaskView(task: Task) -> some View {
    let dateString = dateFormatter.string(
      from: calendar.startOfDay(for: currentDate))

    func editTaskCompleted() {
      if savedData[dateString] == nil {
        savedData[dateString] = [:]
      }
      var taskData =
        savedData[dateString]?[task.id]
        ?? Task(
          id: task.id, name: task.name, completed: false,
          createdAt: task.createdAt,
          deletedAt: task.deletedAt, isEditing: false, editingName: "")
      taskData.completed.toggle()
      print(
        "Toggling task \(task.id) to \(taskData.completed)")
      savedData[dateString]?[task.id] = taskData
      saveContributionData()
    }

    func deleteTask() {
      print("Deleting task", task.id)
      tasks[task.id]?.deletedAt = calendar.startOfDay(
        for: currentDate)
      saveTasksData()
      loadData()
    }

    func editTask() {
      print("Edit")
      tasks[task.id]?.isEditing = true
      tasks[task.id]?.editingName = tasks[task.id]?.name ?? ""
    }

    func taskField() -> some View {
      func editTaskName() {
        if let editingName = tasks[task.id]?.editingName {
          print("Editing task \(task.name) to \(editingName)")
          tasks[task.id]?.name = editingName
          tasks[task.id]?.isEditing = false
          saveTasksData()
        }
      }

      return TextField(
        "Edit task",
        text: Binding(
          get: { tasks[task.id]?.editingName ?? "" },
          set: { tasks[task.id]?.editingName = $0 }
        )
      )
      .onSubmit {
        editTaskName()
      }
      .font(.system(size: 20, design: .serif))
      .textFieldStyle(.plain)
      .background(isDarkMode ? Color.white : Color.black)
      .foregroundColor(isDarkMode ? Color.black : Color.white)
    }

    return SwipeView {
      HStack {
        if task.isEditing {
          taskField()
        } else {
          Text(task.name).font(.system(size: 20, design: .serif))
        }
        Spacer()
        Button(action: {
          editTaskCompleted()
        }) {
          Image(
            systemName: ((savedData[
              dateFormatter.string(
                from: calendar.startOfDay(for: currentDate))
            ]?[
              task.id
            ]?.completed) ?? false)
              ? "checkmark.square.fill" : "square"
          ).font(.system(size: 24))
            .foregroundColor(
              isDarkMode ? Color.white : Color.black)
        }
      }.padding(.horizontal, 20).padding(.vertical, 10)
    } leadingActions: { context in
      SwipeAction("Edit") {
        editTask()
      }
    } trailingActions: { context in
      SwipeAction("Delete") {
        deleteTask()
      }.foregroundStyle(Color.black).background(Color.white)
    }
  }

  func taskListView() -> some View {
    return ScrollView {
      VStack {
        ForEach(
          Array(tasks.values).sorted(by: { $0.name < $1.name }),
          id: \.id
        ) { task in
          singleTaskView(
            task: task)
        }
      }
    }
  }

  func taskView() -> some View {
    return VStack {
      HStack(alignment: .center, spacing: 20) {
        Button(action: {
          currentDate =
            calendar.date(
              byAdding: .day, value: -1, to: currentDate) ?? Date()
          let dateString = dateFormatter.string(
            from: calendar.startOfDay(for: currentDate))
          tasks = savedData[dateString] ?? [:]
          loadData()
        }) {
          Text("<")
            .font(.system(size: 30, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
        }
        Text(
          dateFormatter.string(from: calendar.startOfDay(for: today))
            == dateFormatter.string(from: calendar.startOfDay(for: currentDate))
            ? ("今天 \(dateFormatter.string(from: calendar.startOfDay(for: currentDate)))")
            : (dateFormatter.string(from: calendar.startOfDay(for: currentDate)))
        )
        .font(.system(size: 20, design: .serif))
        Button(action: {
          currentDate =
            calendar.date(
              byAdding: .day, value: 1, to: currentDate) ?? Date()
          let dateString = dateFormatter.string(
            from: calendar.startOfDay(for: currentDate))
          tasks = savedData[dateString] ?? [:]
          loadData()
        }) {
          Text(">")
            .font(.system(size: 30, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
        }
      }
      taskListView()
      addTaskView()
    }
  }

  func trackingView() -> some View {
    return VStack {
      Text("Consistency").font(.system(size: 20, design: .serif))
      Button(action: {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "data")
        defaults.removeObject(forKey: "tasks")
        savedData = [:]
        tasks = [:]
        loadData()
        loadContributionData()
      }) {
        Text("Clear Data")
      }
      ScrollView(.horizontal) {
        LazyHGrid(
          rows: Array(repeating: GridItem(.fixed(35)), count: 7), spacing: 4
        ) {
          ForEach(0..<366) { index in
            ZStack {
              RoundedRectangle(cornerRadius: 2)
                .fill(contributionColor(for: index))
                .border(isDarkMode ? Color.white : Color.black, width: 1)
                .frame(width: 35, height: 35)
              if index == determineTodayIndex() {
                Text("今天")
                  .font(.system(size: 12))
                  .foregroundColor(isDarkMode ? .white : .black)
                  .background(
                    isDarkMode ? .black : .white)
              }
            }
          }
        }
        .padding()
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  var body: some View {
    VStack(alignment: .center) {
      HalftonePattern()
      Text("一致 yīzhí")
        .font(.system(size: 40, design: .serif))
      Spacer()
      Link("by Langpal話朋", destination: URL(string: "https://langpal.com.hk")!)
        .font(.system(size: 16, design: .serif))
        .foregroundColor(.white)
        .overlay(
          Rectangle()
            .frame(height: 1)
            .offset(y: 1)
            .foregroundColor(.white),
          alignment: .bottom
        )
      TabView {
        taskView().tabItem {
          Label("Tasks", systemImage: "list.bullet").foregroundColor(.black)
        }
        trackingView().tabItem {
          Label("Tracking", systemImage: "chart.bar").foregroundColor(.black)
        }.onAppear {
          loadData()
          loadContributionData()
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).onAppear {
        loadData()
        loadContributionData()
        setupNotifications()
      }
    }
  }

  private func determineTodayIndex() -> Int {
    let calendar = Calendar.current
    let today = Date()
    let year = calendar.component(.year, from: today)
    let startOfYear = calendar.startOfYear(for: year)
    let daysSinceStartOfYear =
      calendar.dateComponents([.day], from: startOfYear, to: today).day ?? 0
    return daysSinceStartOfYear
  }

  private func contributionColor(for index: Int) -> Color {
    let intensity = contributionArray[index] / 100.0
    if intensity > 0 {

    }
    return isDarkMode ? Color.white.opacity(intensity) : Color.black.opacity(intensity)
  }
}

#Preview {
  ContentView()
}
