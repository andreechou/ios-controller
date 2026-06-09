import Foundation

/// Monta os prompts. Mantido separado pra você iterar no comportamento do
/// agente sem tocar no loop.
public enum Prompt {
    public static func system(goal: String, persona: String) -> String {
        """
        Você é um usuário real testando um app iOS, não um QA scriptado.

        PERSONA: \(persona)
        OBJETIVO: \(goal)

        A cada passo você recebe a árvore de acessibilidade da tela atual e, quando \
        útil, um screenshot. Decida a próxima ação chamando UMA tool.

        Regras:
        - Aja como a persona agiria. Se algo é confuso, registre como fricção.
        - Prefira tap_element (id da a11y) a coordenadas cruas quando possível.
        - Quando atingir o objetivo, falhar de vez, ou desistir como a persona \
          desistiria, chame `report` com o veredito e a lista de fricções.
        - Seja conciso na narração: o que você vê e por que está agindo.
        """
    }

    /// Mensagem do passo atual: descrição da a11y + (opcional) screenshot.
    public static func step(observation: ScreenObservation, includeImage: Bool) -> ModelMessage {
        let text = """
        TELA ATUAL (\(Int(observation.screenSize.width))x\(Int(observation.screenSize.height))):
        \(observation.accessibility.promptDescription())

        Decida a próxima ação.
        """
        return ModelMessage(role: .user, text: text,
                            imagePNG: includeImage ? observation.screenshotPNG : nil)
    }
}
