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
        let name: String
        var completed: Bool
    }

    struct ContributionData: Decodable, Encodable {
        var dictionary: [String: [Task]] = [:]
    }

    @State var newTask = ""

    @State var currentDate: Date = Date()
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter
    }()

    let calendar = Calendar.current
    let today = Date()

    var savedData: [String: [Task]] {
        let defaults = UserDefaults.standard
        guard let retrievedData = defaults.data(forKey: "data"),
            let decodedData = try? JSONDecoder().decode(ContributionData.self, from: retrievedData)
        else {
            return [:]
        }
        return decodedData.dictionary
    }

    var savedTasks: [Task] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "tasks"),
            let decodedTasks = try? JSONDecoder().decode([Task].self, from: data)
        else {
            return []
        }
        print("Decoded tasks: \(decodedTasks)")
        return decodedTasks
    }

    @State var tasks: [Task] = []
    @State var contributionArray: [Double] = Array(repeating: 0.0, count: 365)

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
        print("Loading data")
        tasks = []
        savedTasks.forEach { task in
            if !(savedData[dateFormatter.string(from: currentDate)]?.contains(where: {
                $0.name == task.name
            }) ?? false) {
                tasks.append(task)
            }
        }

        // saveData()
    }

    func calculateContribution() {
        var newContributionArray = Array(repeating: 0.0, count: 365)

        let calendar = Calendar.current
        let today = Date()
        let year = calendar.component(.year, from: today)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"

        var totalContribution = 0.0

        for dayOffset in 0..<365 {
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
        print("Average Daily Completion for \(year): \(totalContribution / 365.0)%")
    }

    @State var contributionData: ContributionData = ContributionData()

    func saveData() {
        print("Saving data")
        let defaults = UserDefaults.standard

        if let encoded = try? JSONEncoder().encode(tasks) {
            defaults.set(encoded, forKey: "tasks")
        }

        var currentData = savedData
        currentData[dateFormatter.string(from: currentDate)] = tasks
        if let encoded = try? JSONEncoder().encode(ContributionData(dictionary: currentData)) {
            defaults.set(encoded, forKey: "data")
        }
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
                        //trigger post notification in 30 seconds
                        //request permission
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
                    ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                        SwipeView {
                            HStack {
                                Text(task.name).font(.system(size: 20, design: .serif))
                                Spacer()
                                Button(action: {
                                    tasks[index].completed.toggle()
                                    saveData()
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
                                tasks.remove(at: index)
                                saveData()
                            }.foregroundStyle(Color.black).background(Color.white)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity / 2)
            HStack {
                TextField("Add a task", text: $newTask)
                    .font(.system(size: 20, design: .serif))
                    .textFieldStyle(.plain)
                    .padding()
                    .tint(isDarkMode ? Color.white : Color.black)
                    .background(isDarkMode ? Color.black : Color.white).onSubmit {
                        print("Adding task: \(newTask)")
                        tasks.append(Task(name: newTask, completed: false))
                        saveData()
                        newTask = ""
                    }
                Button(action: {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    print("Adding task: \(newTask)")
                    tasks.append(Task(name: newTask, completed: false))
                    saveData()
                    newTask = ""
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
                        ForEach(0..<365) { index in
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
