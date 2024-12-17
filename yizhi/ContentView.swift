//
//  ContentView.swift
//  yizhi
//
//  Created by Devon Crebbin on 17/12/2024.
//

import SwiftUI
import SwipeActions

// Helper extension
extension Calendar {
    fileprivate func startOfYear(for year: Int) -> Date {
        date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }
}

struct ContentView: View {

    struct Task {
        let name: String
        var completed: Bool
    }

    @State var newTask = ""

    var todaysDate: String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: date)
    }

    var savedData: [String: [Task]] {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "data") as? [String: [Task]] ?? [:]
    }

    var savedTasks: [Task] {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "tasks") as? [Task] ?? []
    }

    @State var tasks: [Task] = [Task(name: "Drink water", completed: false)]

    func saveTask(task: Task) {
        tasks.append(task)
        saveData()
        calculateContribution()
    }
    @State var contributionArray: [Double] = Array(repeating: 0.0, count: 365)

    func calculateContribution() {
        let defaults = UserDefaults.standard
        let data = defaults.object(forKey: "data") as? [String: [Task]] ?? [:]

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

                if let tasks = data[dateString] {
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

    // save data to user defaults
    func saveData() {
        let defaults = UserDefaults.standard
        defaults.set(savedTasks, forKey: "tasks")
        var data = savedData
        data[todaysDate] = tasks
        defaults.set(data, forKey: "data")
    }

    var body: some View {
        VStack(alignment: .center) {
            Text("一只 yīzhí").font(.system(size: 40))
            ScrollView {
                Text("今天 / \(todaysDate)").font(.system(size: 20))
                ForEach(Array(tasks.enumerated()), id: \.offset) { index, task in
                    SwipeView {
                        HStack {
                            Text(task.name)
                            Spacer()
                            Button(action: {
                                tasks[index].completed.toggle()
                            }) {
                                Image(
                                    systemName: tasks[index].completed
                                        ? "checkmark.square.fill" : "square"
                                ).font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 10)
                            .background(Color.white)
                    } trailingActions: { context in
                        SwipeAction("Delete") {
                            tasks.remove(at: index)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white)
                        .cornerRadius(0)
                        .background(.black)
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity / 2)
            HStack {
                TextField("Add a task", text: $newTask)
                    .textFieldStyle(.plain)
                    .padding()
                    .tint(.black)
                Button(action: {
                    tasks.append(Task(name: newTask, completed: false))
                    newTask = ""
                }) {
                    Text("ADD").foregroundColor(.black)
                }
            }.padding(.horizontal, 25)
            VStack {
                Text("Consistency").font(.system(size: 20))
                ScrollView(.horizontal) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(40)), count: 7), spacing: 4) {
                        ForEach(0..<365) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(contributionColor(for: index))
                                .border(Color.black, width: 1)
                                .frame(width: 40, height: 40)
                        }
                    }
                    .padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
        .onAppear {
            calculateContribution()
        }
    }

    private func contributionColor(for index: Int) -> Color {
        let intensity = contributionArray[index]
        return Color.black.opacity(intensity)
    }
}

#Preview {
    ContentView()
}
