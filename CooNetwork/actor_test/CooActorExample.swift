//
//  CooActorExample.swift
//  CooNetwork
//
//  Created by 李奇奇 on 2025/7/17.
//

import Foundation

struct School {
    
    func play() async -> String {
        print("play 1")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        print("play 2")
        return "play"
    }
    
    func goToClass() {
        
    }
}


@NtkActor
class CooActorExample {
    
    var age: Int = 18
    
    var name: String = "lqq"
    
    let school: School = School()
    
    func modifyName(_ name: String) {
        self.name = name
    }
    
    func changeSchool() async {
        print("change 1")
        school.goToClass()
        _ = await school.play()
        Task {
            print("change task 1")
            let s = await school.play()
            print("change task 2")
        }
        print("change 2")
        try? await Task.sleep(nanoseconds: 5_000_000_000)  // 异步等待，不阻塞线程
        print("change 3")
    }
    
}
