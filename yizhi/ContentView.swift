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
        let name: String
        var completed: Bool
        var createdAt: Date
        var deletedAt: Date?
    }

    struct ContributionData: Decodable, Encodable {
        var dictionary: [String: [Task]] = [:]
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

    @State var savedData: [String: [Task]] = [:]

    var savedTasks: [Task] = []

    @State var tasks: [Task] = []
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
            print("Loaded contribution data:", decodedContributionData)
        }

        if let retrievedTasksData = defaults.data(forKey: "tasks"),
            let decodedTasks = try? JSONDecoder().decode([Task].self, from: retrievedTasksData)
        {
            tasks = decodedTasks
        }

        tasks = tasks.filter { task in
            task.deletedAt != nil
                ? (calendar.startOfDay(for: task.deletedAt!) >= startOfDay
                    && calendar.startOfDay(for: task.createdAt) <= startOfDay)
                : calendar.startOfDay(for: task.createdAt) <= startOfDay
        }

        print("Today's tasks:", tasks)
    }

    func calculateContribution() {
        var newContributionArray = Array(repeating: 0.0, count: 366)

        let calendar = Calendar.current
        let today = Date()
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

                if let tasks = savedData[dateString] {
                    let completedCount = tasks.filter(\.completed).count
                    let percentage =
                        tasks.isEmpty ? 0.0 : (Double(completedCount) / Double(tasks.count)) * 100.0

                    totalContribution += percentage
                    newContributionArray[dayOffset] = percentage
                }
            }
        }

        contributionArray = newContributionArray
        print("Average Daily Completion for \(year): \(totalContribution / 366.0)%")
    }

    @State var contributionData: ContributionData = ContributionData()

    func addTask() {
        print("Adding task: \(newTaskName), created at: \(currentDate)")
        tasks.append(
            Task(
                id: UUID().uuidString,
                name: newTaskName, completed: false, createdAt: currentDate,
                deletedAt: nil
            )
        )
        saveTasksData()
        newTaskName = ""
    }

    func saveContributionData() {
        let defaults = UserDefaults.standard
        savedData[dateFormatter.string(from: calendar.startOfDay(for: currentDate))] = tasks
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

    var body: some View {
        VStack(alignment: .center) {
            HalftonePattern()
            Text("一致 yīzhí")
                .font(.system(size: 40, design: .serif))
            ScrollView {
                VStack {
                    Button(action: {
                        UNUserNotificationCenter.current().requestAuthorization(options: [
                            .alert, .sound, .badge,
                        ]) {
                            (granted, error) in
                            if granted {
                                print("Notification permission granted")
                            } else {
                                print("Notification permission denied")
                            }
                        }

                        let content = UNMutableNotificationContent()
                        content.title = "一致"
                        content.body = "Time to update your tasks!\n现在更新你的任务吧！"
                        let trigger = UNTimeIntervalNotificationTrigger(
                            timeInterval: 5, repeats: false)
                        let request = UNNotificationRequest(
                            identifier: "一致", content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request)
                    }) {
                        Text("Notif")
                    }
                    HStack {
                        Button(action: {
                            currentDate =
                                calendar.date(
                                    byAdding: .day, value: -1, to: currentDate) ?? Date()
                            let dateString = dateFormatter.string(from: currentDate)
                            tasks = savedData[dateString] ?? []
                            loadData()
                        }) {
                            Text("<")
                                .font(.system(size: 20, design: .serif))
                                .foregroundColor(isDarkMode ? Color.white : Color.black)
                        }
                        Text(
                            dateFormatter.string(from: currentDate)
                                == dateFormatter.string(from: today)
                                ? ("今天 \(dateFormatter.string(from: today))")
                                : (dateFormatter.string(from: currentDate))
                        )
                        .font(.system(size: 20, design: .serif))
                        Button(action: {
                            currentDate =
                                calendar.date(
                                    byAdding: .day, value: 1, to: currentDate) ?? Date()
                            let dateString = dateFormatter.string(from: currentDate)
                            tasks = savedData[dateString] ?? []
                            loadData()
                        }) {
                            Text(">")
                                .font(.system(size: 20, design: .serif))
                                .foregroundColor(isDarkMode ? Color.white : Color.black)
                        }
                    }
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        SwipeView {
                            HStack {
                                Text(task.name).font(.system(size: 20, design: .serif))
                                Spacer()
                                Button(action: {
                                    tasks[index].completed.toggle()
                                    saveContributionData()
                                }) {
                                    Image(
                                        systemName: tasks[index].completed
                                            ? "checkmark.square.fill" : "square"
                                    ).font(.system(size: 24))
                                        .foregroundColor(isDarkMode ? Color.white : Color.black)
                                }
                            }.padding(.horizontal, 20).padding(.vertical, 10)
                        } trailingActions: { context in
                            SwipeAction("Delete") {
                                tasks[index].deletedAt = calendar.startOfDay(for: currentDate)
                                saveTasksData()
                            }.foregroundStyle(Color.black).background(Color.white)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity / 2)
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
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    print("Adding task: \(newTaskName), created at: \(Date())")
                    addTask()
                }) {
                    Text("ADD")
                        .foregroundColor(isDarkMode ? Color.white : Color.black)
                        .font(.system(size: 20, design: .serif))
                }
            }.padding(.horizontal, 25)
            VStack {
                Text("Consistency").font(.system(size: 20, design: .serif))
                ScrollView(.horizontal) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(35)), count: 7), spacing: 4) {
                        ForEach(0..<366) { index in
                            ZStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(contributionColor(for: index))
                                    .border(isDarkMode ? Color.white : Color.black, width: 1)
                                    .frame(width: 35, height: 35)
                                if index == determineTodayIndex() {
                                    Text("今天")
                                        .font(.system(size: 12))
                                        .foregroundColor(isDarkMode ? .white : .black).background(
                                            isDarkMode ? .black : .white)
                                }
                            }
                        }
                    }
                    .padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadData()
            loadContributionData()
            setupNotifications()
        }
    }

    private func determineTodayIndex() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)
        let startOfYear = calendar.startOfYear(for: year)
        let daysSinceStartOfYear =
            calendar.dateComponents([.day], from: startOfYear, to: today).day ?? 0
        return daysSinceStartOfYear + 1
    }

    private func contributionColor(for index: Int) -> Color {
        let intensity = contributionArray[index] / 100.0
        return isDarkMode ? Color.white.opacity(intensity) : Color.black.opacity(intensity)
    }
}

#Preview {
    ContentView()
}
