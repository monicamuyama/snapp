"use client"

import { useState, useEffect } from "react"
import type { Goal } from "@/types/sacco"
import { getGoals, addGoal, updateGoal, deleteGoal } from "@/lib/storage/goals"

export function useGoals() {
  const [goals, setGoals] = useState<Goal[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const loadGoals = () => {
      const storedGoals = getGoals()
      setGoals(storedGoals)
      setIsLoading(false)
    }

    loadGoals()
  }, [])

  const createGoal = (goalData: Omit<Goal, "id">) => {
    const newGoal = addGoal(goalData)
    setGoals((prev) => [...prev, newGoal])
    return newGoal
  }

  const modifyGoal = (id: string, updates: Partial<Goal>) => {
    updateGoal(id, updates)
    setGoals((prev) => prev.map((goal) => (goal.id === id ? { ...goal, ...updates } : goal)))
  }

  const removeGoal = (id: string) => {
    deleteGoal(id)
    setGoals((prev) => prev.filter((goal) => goal.id !== id))
  }

  const addProgress = (id: string, amount: number) => {
    const goal = goals.find((g) => g.id === id)
    if (!goal) return

    const newAmount = goal.currentAmount + amount
    const completed = newAmount >= goal.targetAmount

    modifyGoal(id, {
      currentAmount: newAmount,
      completed,
    })
  }

  return {
    goals,
    isLoading,
    createGoal,
    modifyGoal,
    removeGoal,
    addProgress,
  }
}
