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
  var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
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
    .frame(maxWidth: .infinity, maxHeight: isIPad ? 130 : 70)
    .background(Color.clear)
    .clipped()
  }

  private func getDotScale(row: Int) -> CGFloat {
    let progress = CGFloat(row) / CGFloat(rows)
    return 1.0 - progress
  }
}

struct ContentView: View {

  var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }
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

  func loadData() {
    let defaults = UserDefaults.standard
    let startOfDay = calendar.startOfDay(for: currentDate)
    let todayString = dateFormatter.string(from: startOfDay)

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

          totalContribution += percentage
          newContributionArray[dayOffset] = percentage
        }
      }
    }
    contributionArray = newContributionArray
  }

  @State var contributionData: ContributionData = ContributionData()

  func addTask() {
    if newTaskName.isEmpty || newTaskName == "" {
      return
    }

    let id = UUID().uuidString
    savedTasks[id] = Task(
      id: id,
      name: newTaskName, completed: false, createdAt: currentDate,
      deletedAt: nil
    )
    tasks[id] = savedTasks[id]
    saveTasksData()
    newTaskName = ""
  }

  func saveContributionData() {
    let defaults = UserDefaults.standard
    let encoded = try? JSONEncoder().encode(ContributionData(dictionary: savedData))
    defaults.set(encoded, forKey: "data")
  }

  func saveTasksData() {
    let defaults = UserDefaults.standard
    let encoded = try? JSONEncoder().encode(savedTasks)
    defaults.set(encoded, forKey: "tasks")
  }

  private func loadContributionData() {
    calculateContribution()
  }

  func addTaskView() -> some View {
    HStack {
      TextField("Add new task", text: $newTaskName)
        .font(.system(size: isIPad ? 30 : 20, design: .serif))
        .textFieldStyle(.plain)
        .padding()
        .tint(isDarkMode ? Color.white : Color.black).onSubmit {
          addTask()
        }
      Button(action: {
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil,
          for: nil)
        addTask()
      }) {
        Text("ADD")
          .foregroundColor(isDarkMode ? Color.white : Color.black)
          .font(.system(size: isIPad ? 30 : 20, design: .serif))
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
      savedData[dateString]?[task.id] = taskData
      saveContributionData()
    }

    func deleteTask() {
      tasks[task.id]?.deletedAt = calendar.startOfDay(
        for: currentDate)
      saveTasksData()
      loadData()
    }

    func editTask() {
      tasks[task.id]?.isEditing = true
      tasks[task.id]?.editingName = tasks[task.id]?.name ?? ""
    }

    func taskField() -> some View {
      func editTaskName() {
        if let editingName = tasks[task.id]?.editingName {
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
      .font(.system(size: isIPad ? 30 : 20, design: .serif))
      .textFieldStyle(.plain)
      .background(isDarkMode ? Color.white : Color.black)
      .foregroundColor(isDarkMode ? Color.black : Color.white)
    }

    return SwipeView {
      HStack {
        if task.isEditing {
          taskField()
        } else {
          Text(task.name).font(.system(size: isIPad ? 30 : 20, design: .serif))
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
          ).font(.system(size: isIPad ? 30 : 24))
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
            .font(.system(size: isIPad ? 30 : 20, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
        }
        Text(
          dateFormatter.string(from: calendar.startOfDay(for: today))
            == dateFormatter.string(from: calendar.startOfDay(for: currentDate))
            ? ("今天 \(dateFormatter.string(from: calendar.startOfDay(for: currentDate)))")
            : (dateFormatter.string(from: calendar.startOfDay(for: currentDate)))
        )
        .font(.system(size: isIPad ? 30 : 20, design: .serif))
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
            .font(.system(size: isIPad ? 30 : 20, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
        }
      }
      taskListView()
      addTaskView()
    }.padding(.horizontal, isIPad ? 50 : 20)
  }

  func trackingView() -> some View {
    return VStack {
      Button(action: {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "data")
        defaults.removeObject(forKey: "tasks")
        savedData = [:]
        tasks = [:]
        loadData()
        loadContributionData()
      }) {
        HStack {
          Text("Clear Data")
            .font(.system(size: isIPad ? 30 : 20, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
          Image(systemName: "trash")
            .font(.system(size: isIPad ? 30 : 20, design: .serif))
            .foregroundColor(isDarkMode ? Color.white : Color.black)
        }
      }
      ScrollView(.vertical) {
        LazyVGrid(
          columns: Array(repeating: GridItem(.fixed(isIPad ? 75 : 35)), count: 7), spacing: 4
        ) {
          ForEach(0..<366) { index in
            ZStack {
              RoundedRectangle(cornerRadius: 2)
                .fill(contributionColor(for: index))
                .border(isDarkMode ? Color.white : Color.black, width: 1)
                .frame(width: isIPad ? 75 : 35, height: isIPad ? 75 : 35)
              if index == determineTodayIndex() {
                Text("今天")
                  .font(.system(size: isIPad ? 20 : 12, design: .serif))
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
        .font(.system(size: isIPad ? 50 : 24, design: .serif))
      Spacer()
      HStack {
        Link("by Langpal話朋", destination: URL(string: "https://langpal.com.hk")!)
          .font(.system(size: isIPad ? 20 : 16, design: .serif))
          .foregroundColor(isDarkMode ? .white : .black)
          .overlay(
            Rectangle()
              .frame(height: 1)
              .offset(y: 1)
              .foregroundColor(isDarkMode ? .white : .black),
            alignment: .bottom
          )
        Link(destination: URL(string: "mailto:devon@langpal.com.hk")!) {
          Image(systemName: "envelope")
            .font(.system(size: isIPad ? 20 : 10, design: .serif))
            .foregroundColor(isDarkMode ? .white : .black)
        }
      }
      TabView {
        taskView()
          .tabItem {
            Label("Tasks", systemImage: "list.bullet")
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        trackingView()
          .tabItem {
            Label("Tracking", systemImage: "chart.bar")
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .onAppear {
            loadData()
            loadContributionData()
          }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accentColor(isDarkMode ? .white : .black)
      .onAppear {
        loadData()
        loadContributionData()

        // Set tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = isDarkMode ? .black : .white

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
          UITabBar.appearance().scrollEdgeAppearance = appearance
        }
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
